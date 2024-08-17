{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2024 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
{                                                                              }
{******************************************************************************}

unit web3.eth.eip712;

{$I web3.inc}

interface

uses
  // Delphi
  System.Generics.Collections,
  System.SysUtils,
  System.Variants,
  // CryptoLib4Pascal
  ClpBigInteger,
  ClpBigIntegers,
  // web3
  web3,
  web3.error,
  web3.utils;

type
  // TType is the inner type of an EIP-712 message
  TType = record
  private
    FName: string;
    FType: string;
  public
    constructor Create(const aName, aType: string);
    property Name: string read FName;
    property &Type: string read FType;
  end;

  TTypes = class(TDictionary<string, TArray<TType>>)
  private
    function Validate: IError;
  public
    constructor Create;
  end;

  ITypedMessage = interface
  ['{9C4C114F-B686-4AE4-AF53-5636ED6B7395}']
    procedure Add(const Key: string; const Value: Variant);
    function Count: NativeInt;
    function GetItem(const Key: string): Variant;
  end;

  // TTypedDomain represents the domain part of an EIP-712 message.
  TTypedDomain = class(TObject)
  private
    FName: string;
    FVersion: string;
    FChainId: UInt64;
    FVerifyingContract: string;
    function Validate: IError;
  public
    function Map: ITypedMessage;
    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property ChainId: UInt64 read FChainId write FChainId;
    property VerifyingContract: string read FVerifyingContract write FVerifyingContract;
  end;

  TValidateAction = (vaTypes, vaDomain, vaPrimaryType);
  TWhatToValidate = set of TValidateAction;

  // TTypedData is a type to encapsulate EIP-712 typed messages
  TTypedData = class(TObject)
  private
    FTypes: TTypes;
    FPrimaryType: string;
    FDomain: TTypedDomain;
    FMessage: ITypedMessage;
    function Validate(const what: TWhatToValidate): IError;
    function Dependencies(primaryType: string; found: TArray<string>): TArray<string>;
    function EncodeType(const primaryType: string): TBytes;
    function TypeHash(const primaryType: string): TBytes;
    class function DataMismatchError(const encType: string; const encValue: Variant): IError;
    function EncodePrimitiveValue(const encType: string; const encValue: Variant; const depth: Integer): IResult<TBytes>;
    function EncodeData(const primaryType: string; const data: ITypedMessage; const depth: Integer; const validate: TWhatToValidate): IResult<TBytes>;
  public
    constructor Create;
    destructor Destroy; override;
    function HashStruct(const primaryType: string; const data: ITypedMessage; const validate: TWhatToValidate): IResult<TBytes>;
    property Types: TTypes read FTypes;
    property PrimaryType: string read FPrimaryType write FPrimaryType;
    property Domain: TTypedDomain read FDomain;
    property Message: ITypedMessage read FMessage;
  end;

implementation

{---------------- TType is the inner type of an EIP-712 message ---------------}

constructor TType.Create(const aName, aType: string);
begin
  Self.FName := aName;
  Self.FType := aType;
end;

{----------------------------------- TTypes -----------------------------------}

constructor TTypes.Create;
begin
  inherited Create;

  Self.Add('EIP712Domain', [
    TType.Create('name',              'string'),
    TType.Create('version',           'string'),
    TType.Create('chainId',           'uint256'),
    TType.Create('verifyingContract', 'address')
  ]);
end;

// Validate checks if the types object is conformant to the specs
function TTypes.Validate: IError;

  function isPrimitiveTypeValid(const primitiveType: string): Boolean;
  begin
    Result := (primitiveType = 'address')
           or (primitiveType = 'address[]')
           or (primitiveType = 'bool')
           or (primitiveType = 'bool[]')
           or (primitiveType = 'string')
           or (primitiveType = 'string[]')
           or (primitiveType = 'bytes')
           or (primitiveType = 'bytes[]')
           or (primitiveType = 'int')
           or (primitiveType = 'int[]')
           or (primitiveType = 'uint')
           or (primitiveType = 'uint[]');
    if not Result then
    begin
      // for bytesₓ and bytesₓ[] we allow ₓ from 1 to 32
      for var n := 1 to 32 do
      begin
        Result := (primitiveType = Format('bytes%d', [n])) or (primitiveType = Format('bytes%d[]', [n]));
        if Result then EXIT;
      end;
      // for intₓ and intₓ[] and uintₓ and uintₓ[] we allow ₓ in increments of 8, from 8 up to 256
      var n := 8;
      while n <= 256 do
      begin
        Result := (primitiveType = Format('int%d', [n])) or (primitiveType = Format('int%d[]', [n])) or
                  (primitiveType = Format('uint%d', [n])) or (primitiveType = Format('uint%d[]', [n]));
        if Result then EXIT;
        n := n + 8;
      end;
    end;
  end;

begin
  for var pair in Self do
  begin
    if pair.Key.Length = 0 then
    begin
      Result := TError.Create('empty type key');
      EXIT;
    end;
    for var &type in pair.Value do
    begin
      if &type.Name.Length = 0 then
      begin
        Result := TError.Create('empty Name');
        EXIT;
      end;
      if &type.&Type.Length = 0 then
      begin
        Result := TError.Create('empty Type');
        EXIT;
      end;
      if pair.Key = &type.&Type then
      begin
        Result := TError.Create('type %s cannot reference itself', [&type.&Type]);
        EXIT;
      end;
      if not isPrimitiveTypeValid(&type.&Type) then
      begin
        Result := TError.Create('%s is not a valid primitive type', [&type.&Type]);
        EXIT;
      end;
    end;
  end;
  Result := nil;
end;

{------------------------------- TTypedMessage --------------------------------}

type
  TTTypedMessage = class(TInterfacedObject, ITypedMessage)
  private
    FInner: TDictionary<string, Variant>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Key: string; const Value: Variant);
    function Count: NativeInt;
    function GetItem(const Key: string): Variant;
  end;

constructor TTTypedMessage.Create;
begin
  inherited Create;
  FInner := TDictionary<string, Variant>.Create;
end;

destructor TTTypedMessage.Destroy;
begin
  if Assigned(FInner) then FInner.Free;
  inherited Destroy;
end;

procedure TTTypedMessage.Add(const Key: string; const Value: Variant);
begin
  FInner.Add(Key, Value);
end;

function TTTypedMessage.Count: NativeInt;
begin
  Result := FInner.Count;
end;

function TTTypedMessage.GetItem(const Key: string): Variant;
begin
  Result := FInner.Items[Key];
end;

{------- TTypedDomain represents the domain part of an EIP-712 message --------}

function TTypedDomain.Map: ITypedMessage;
begin
  Result := TTTypedMessage.Create;
  if Self.ChainId > 0 then
    Result.Add('chainId', Self.ChainId);
  if Self.Name.Length > 0 then
    Result.Add('name', Self.Name);
  if Self.Version.Length > 0 then
    Result.Add('version', Self.Version);
  if Self.VerifyingContract.Length > 0 then
    Result.Add('verifyingContract', Self.VerifyingContract);
end;

// Validate checks if the given domain is valid, i.e. contains at least the minimum viable keys and values
function TTypedDomain.Validate: IError;
begin
  if (Self.ChainId = 0) and (Self.Name.Length = 0) and (Self.Version.Length = 0) and (Self.VerifyingContract.Length = 0) then
    Result := TError.Create('domain is undefined')
  else
    Result := nil;
end;

{--------- TTypedData is a type to encapsulate EIP-712 typed messages ---------}

constructor TTypedData.Create;
begin
  inherited Create;
  FTypes := TTypes.Create;
  FDomain := TTypedDomain.Create;
  FMessage := TTTypedMessage.Create;
end;

destructor TTypedData.Destroy;
begin
  if Assigned(FMessage) then FMessage := nil;
  if Assigned(FDomain) then FDomain.Free;
  if Assigned(FTypes) then FTypes.Free;
  inherited Destroy;
end;

function TTypedData.Validate(const what: TWhatToValidate): IError;
begin
  Result := nil;
  if (vaTypes in what) then
    Result := Self.Types.Validate;
  if (Result = nil) and (vaDomain in what) then
    Result := Self.Domain.Validate;
  if (Result = nil) and (vaPrimaryType in what) then
    if Self.PrimaryType.Length = 0 then Result := TError.Create('PrimaryType is empty');
end;

// Dependencies returns an array of custom types ordered by their hierarchical reference tree
function TTypedData.Dependencies(primaryType: string; found: TArray<string>): TArray<string>;
begin
  if primaryType.EndsWith('[]') then Delete(primaryType, High(primaryType) - 1, 2);

  if TArray.Contains<string>(found, primaryType) then
  begin
    Result := found;
    EXIT;
  end;

  if not Self.Types.ContainsKey(primaryType) then
  begin
    Result := found;
    EXIT;
  end;

  found := found + [primaryType];
  for var field in Self.Types[primaryType] do
    for var dep in Self.Dependencies(field.&Type, found) do
      if not TArray.Contains<string>(found, dep) then
        found := found + [dep];

  Result := found;
end;

// EncodeType generates the following encoding: `name ‖ "(" ‖ member₁ ‖ "," ‖ member₂ ‖ "," ‖ … ‖ memberₓ ")"`
// Note: each member is written as `type ‖ " " ‖ name` encodings cascade down and are sorted by name.
function TTypedData.EncodeType(const primaryType: string): TBytes;
begin
  // get dependencies primary first, then alphabetical
  var deps: TArray<string> := Self.Dependencies(primaryType, []);
  if Length(deps) > 0 then
  begin
    Delete(deps, 0, 1);
    TArray.Sort<string>(deps);
    deps := [primaryType] + deps;
  end;
  // format as a string with fields
  const buffer = TStringBuilder.Create;
  try
    for var dep in deps do
    begin
      buffer.Append(dep);
      buffer.Append('(');
      for var obj in Self.Types[dep] do
      begin
        buffer.Append(obj.&Type);
        buffer.Append(' ');
        buffer.Append(obj.Name);
        buffer.Append(',')
      end;
      buffer.Length := buffer.Length - 1;
      buffer.Append(')');
    end;
    Result := TEncoding.UTF8.GetBytes(buffer.ToString);
  finally
    buffer.Free;
  end;
end;

// TypeHash creates the keccak256 hash of the data
function TTypedData.TypeHash(const primaryType: string): TBytes;
begin
  Result := web3.utils.sha3(Self.EncodeType(primaryType));
end;

// DataMismatchError generates an error for a mismatch between the provided type and data
class function TTypedData.DataMismatchError(const encType: string; const encValue: Variant): IError;
begin
  Result := TError.Create('provided data %s doesn''t match type %s', [VarTypeAsText(VarType(encValue)), encType]);
end;

// EncodePrimitiveValue deals with the primitive values found while searching through the typed data
function TTypedData.EncodePrimitiveValue(const encType: string; const encValue: Variant; const depth: Integer): IResult<TBytes>;

  function parseBytes(const encType: string; const encValue: Variant): IResult<TBytes>;
  begin
    if VarIsStr(encValue) then
    begin
      const str = VarToStr(encValue).Trim;
      if web3.utils.isHex(str) then
      begin
        Result := TResult<TBytes>.Ok(web3.utils.fromHex(str));
        EXIT;
      end;
    end;
    const vt = VarType(encValue);
    if ((vt and varArray) = varArray) and ((vt and varTypeMask) = varByte) then
    begin
      Result := TResult<TBytes>.Ok(TBytes(encValue));
      EXIT;
    end;
    Result := TResult<TBytes>.Err([], Format('invalid value for type %s', [encType]));
  end;

  function parseInteger(const encType: string; const encValue: Variant): IResult<TBigInteger>;
  begin
    if VarIsStr(encValue) then
    begin
      var str := VarToStr(encValue).Trim;
      try
        if web3.utils.isHex(str) then
        begin
          if str.StartsWith('0x') then Delete(str, System.Low(str), 2); // trim "0x"
          if str.Length mod 2 > 0 then str := '0' + str;                // pad to even
          Result := TResult<TBigInteger>.Ok(TBigInteger.Create(str, 16));
        end else
          Result := TResult<TBigInteger>.Ok(TBigInteger.Create(str));
      except
        Result := TResult<TBigInteger>.Err(TBigInteger.Zero, Format('%s is not a valid integer value', [str]));
      end;
      EXIT;
    end;
    if VarType(encValue) in [varShortInt, varSmallInt, varInteger, varInt64] then
      Result := TResult<TBigInteger>.Ok(TBigInteger.Create(IntToStr(encValue)))
    else if VarType(encValue) in [varByte, varWord, varLongWord, varUInt32, varUInt64] then
      Result := TResult<TBigInteger>.Ok(TBigInteger.Create(UIntToStr(encValue)))
    else
      Result := TResult<TBigInteger>.Err(TBigInteger.Zero, Format('invalid integer value for type %s', [encType]));
  end;

begin
  {--------------------------------- address ----------------------------------}
  if encType = 'address' then
  begin
    if VarIsStr(encValue) and web3.utils.isHex(VarToStr(encValue)) then
    begin
      var buf := web3.utils.fromHex(VarToStr(encValue)); // probably 20 bytes
      if Length(buf) < 32 then repeat buf := [0] + buf until Length(buf) = 32;
      if Length(buf) > 32 then
        Result := TResult<TBytes>.Err([], Format('address too long. expected 20 bytes, got %d bytes', [Length(buf)]))
      else
        Result := TResult<TBytes>.Ok(buf);
    end else
      Result := TResult<TBytes>.Err([], DataMismatchError(encType, encValue));
  {----------------------------------- bool -----------------------------------}
  end else if encType = 'bool' then
  begin
    if not VarIsType(encValue, varBoolean) then
      Result := TResult<TBytes>.Err([], DataMismatchError(encType, encValue))
    else if encValue then
      Result := TResult<TBytes>.Ok([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1])
    else
      Result := TResult<TBytes>.Ok([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]);
  {---------------------------------- string ----------------------------------}
  end else if encType = 'string' then
  begin
    if VarIsStr(encValue) then
      Result := TResult<TBytes>.Ok(web3.utils.sha3(TEncoding.UTF8.GetBytes(VarToStr(encValue))))
    else
      Result := TResult<TBytes>.Err([], DataMismatchError(encType, encValue));
  {---------------------------------- bytes -----------------------------------}
  end else if encType = 'bytes' then
  begin
    const parsed = parseBytes(encType, encValue);
    if parsed.IsErr then
      Result := TResult<TBytes>.Err([], parsed.Error)
    else
      Result := TResult<TBytes>.Ok(web3.utils.sha3(parsed.Value));
  {---------------------------------- bytesₓ ----------------------------------}
  end else if encType.StartsWith('bytes') then
  begin
    const len = (function: IResult<Integer>
    begin
      var len := encType; Delete(len, Low(len), 5); // trim "bytes"
      try
        Result := TResult<Integer>.Ok(StrToInt(len));
      except
        on E: Exception do Result := TResult<Integer>.Err(0, E.Message);
      end;
    end)();
    if len.IsErr then
    begin
      Result := TResult<TBytes>.Err([], len.Error);
      EXIT;
    end;
    if (len.Value < 0) or (len.Value > 32) then
    begin
      Result := TResult<TBytes>.Err([], Format('invalid size on bytes: %d', [len.Value]));
      EXIT;
    end;
    const parsed = parseBytes(encType, encValue);
    if parsed.IsErr then
    begin
      Result := TResult<TBytes>.Err([], parsed.Error);
      EXIT;
    end;
    if Length(parsed.Value) <> len.Value then
    begin
      Result := TResult<TBytes>.Err([], DataMismatchError(encType, encValue));
      EXIT;
    end;
    var bytes := parsed.Value;
    if Length(bytes) < 32 then repeat bytes := bytes + [0] until Length(bytes) = 32;
    Result := TResult<TBytes>.Ok(bytes);
  {------------------------------ intₓ or uintₓ -------------------------------}
  end else if encType.StartsWith('int') or encType.StartsWith('uint') then
  begin
    const parsed = parseInteger(encType, encValue);
    if parsed.IsErr then
      Result := TResult<TBytes>.Err([], parsed.Error)
    else
      Result := TResult<TBytes>.Ok(TBigIntegers.BigIntegerToBytes(parsed.Value, 32));
  {------------------------- error: unrecognized type -------------------------}
  end else
    Result := TResult<TBytes>.Err([], Format('unrecognized type %s', [encType]));
end;

// EncodeData generates the following encoding: `enc(value₁) ‖ enc(value₂) ‖ … ‖ enc(valueₓ)`
// Note: each encoded member is 32-byte long.
function TTypedData.EncodeData(
  const primaryType: string;
  const data       : ITypedMessage;
  const depth      : Integer;
  const validate   : TWhatToValidate): IResult<TBytes>;
begin
  const err = Self.Validate(validate);
  if Assigned(err) then
  begin
    Result := TResult<TBytes>.Err([], err);
    EXIT;
  end;

  // verify extra data
  const exp = Length(Self.Types[primaryType]);
  const got = data.Count;
  if exp < got then
  begin
    Result := TResult<TBytes>.Err([], Format('there is extra data provided in the message (%d < %d)', [exp, got]));
    EXIT;
  end;

  // add typehash
  var buffer: TBytes := Self.TypeHash(primaryType);

  // add field contents. structs and arrays have special handlers.
  for var field in Self.Types[primaryType] do
  begin
    const encType : string  = field.&Type;
    const encValue: Variant = data.GetItem(field.Name);
    if encType.EndsWith(']') then
      Result := TResult<TBytes>.Err([], TNotImplemented.Create) // ToDo: implement
    else
      if Self.Types.ContainsKey(field.&Type) then
      begin
        const mapValue = (function: ITypedMessage
        begin
          Result := nil;
          if VarType(encValue) = varUnknown then
          begin
            var msg: ITypedMessage;
            if Supports(encValue, ITypedMessage, msg) then Result := msg;
          end;
        end)();
        if not Assigned(mapValue) then // mismatch between the provided type and data
        begin
          Result := TResult<TBytes>.Err([], DataMismatchError(encType, encValue));
          EXIT;
        end;
        const encodedData = Self.EncodeData(field.&Type, mapValue, depth + 1, validate);
        if encodedData.isErr then
        begin
          Result := TResult<TBytes>.Err([], encodedData.Error);
          EXIT;
        end;
        buffer := buffer + web3.utils.sha3(encodedData.Value);
      end else
      begin
        const byteValue = Self.EncodePrimitiveValue(encType, encValue, depth);
        if byteValue.IsErr then
        begin
          Result := TResult<TBytes>.Err([], byteValue.Error);
          EXIT;
        end;
        buffer := buffer + byteValue.Value;
      end;
  end;

  Result := TResult<TBytes>.Ok(buffer);
end;

// HashStruct generates a keccak256 hash of the encoding of the provided data
function TTypedData.HashStruct(
  const primaryType: string;
  const data       : ITypedMessage;
  const validate   : TWhatToValidate): IResult<TBytes>;
begin
  const encodedData = Self.EncodeData(primaryType, data, 1, validate);
  if encodedData.IsErr then
    Result := TResult<TBytes>.Err([], encodedData.Error)
  else
    Result := TResult<TBytes>.Ok(web3.utils.sha3(encodedData.Value));
end;

end.
