{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.abi;

{$I web3.inc}

interface

uses
  // Delphi
  System.Generics.Collections,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3;

type
  TContractArray = TList<Variant>;

  IContractStruct = interface
  ['{CA0C794D-6280-4AB1-9E91-4DE3443DFD1B}']
    function Tuple: TArray<Variant>;
  end;

function tuple(args: array of Variant): Variant;

function &array(args: array of Variant): TContractArray; overload;
function &array(args: array of TAddress): TContractArray; overload;
function &array(args: array of BigInteger): TContractArray; overload;

function encode(const func: string; args: array of const): string;

implementation

uses
  // Delphi
  System.SysUtils,
  System.Variants,
  // web3
  web3.utils;

function tuple(args: array of Variant): Variant;
var
  I: Integer;
begin
  Result := VarArrayCreate([0, High(args)], varVariant);
  for I := 0 to High(args) do Result[I] := args[I];
end;

function &array(args: array of Variant): TContractArray;
var
  arg: Variant;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(arg);
end;

function &array(args: array of TAddress): TContractArray;
var
  arg: TAddress;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(arg);
end;

function &array(args: array of BigInteger): TContractArray;
var
  arg: BigInteger;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(web3.utils.toHex(arg));
end;

function encode(const func: string; args: array of const): string;

  // https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI#argument-encoding
  function encodeArgs(args: array of const): TBytes;

    function encodeArg(bool: Boolean): TBytes; overload;
    begin
      Result := web3.utils.fromHex('0x' + IntToHex(Ord(bool), 64));
    end;

    function encodeArg(int: Integer): TBytes; overload;
    begin
      Result := web3.utils.fromHex('0x' + IntToHex(int, 64));
    end;

    function encodeArg(int: Int64): TBytes; overload;
    begin
      Result := web3.utils.fromHex('0x' + IntToHex(int, 64));
    end;

    function encodeArg(const str: string): TBytes; overload;
    var
      buf: TBytes;
      hex: string;
    begin
      var prefix := Copy(str, System.Low(str), 2).ToLower;
      if prefix <> '0x' then
      begin
        if prefix = '0b' then // bytes
        begin
          hex := web3.utils.toHex(BigInteger.Create(str), [padToEven, noPrefix]);
          buf := web3.utils.fromHex(hex);
        end
        else // string literal
        begin
          buf := TEncoding.UTF8.GetBytes(str);
          hex := web3.utils.toHex('', buf);
        end;
        while (hex = '') or (Length(hex) mod 64 <> 0) do hex := hex + '0';
        if Length(buf) > 0 then hex := IntToHex(Length(buf), 64) + hex;
        hex := '0x' + hex;
      end
      else // number or address
      begin
        buf := web3.utils.fromHex(str);
        if Length(buf) = 32 then
          hex := str
        else
          hex := web3.utils.toHex(buf, 32 - Length(buf), 32);
      end;
      Result := web3.utils.fromHex(hex);
    end;

    function isDynamic(const arg: Variant): Boolean; overload;
    begin
      Result := False;
      case FindVarData(arg)^.VType of
        varUnknown:
        begin
          var S: IContractStruct;
          if Supports(arg, IContractStruct, S) then
            Result := isDynamic(tuple(S.Tuple));
        end;
        varOleStr,
        varStrArg,
        varUStrArg,
        varString,
        varUString:
          Result := Copy(string(arg), System.Low(string(arg)), 2).ToLower <> '0x';
      else
        if VarIsArray(arg) then // tuple is dynamic if any of the elements is dynamic
          for var I := VarArrayLowBound(arg, 1) to VarArrayHighBound(arg, 1) do
          begin
            Result := isDynamic(VarArrayGet(arg, [I]));
            if Result then
              EXIT;
          end;
      end;
    end;

    function varArrayCount(const arg: Variant): Integer;
    begin
      Result := 0;
      if VarIsArray(arg) then
      begin
        Result := VarArrayHighBound(arg, 1) - VarArrayLowBound(arg, 1) + 1;
        for var I := VarArrayLowBound(arg, 1) to VarArrayHighBound(arg, 1) do
          Result := Result + varArrayCount(VarArrayGet(arg, [I]));
      end;
    end;

    function encodeArg(const arg: Variant): TBytes; overload;
    var
      idx   : Integer;
      elem  : Variant;
      curr  : TBytes;
      suffix: TBytes;
      offset: Integer;
      struct: IContractStruct;
    begin
      Result := [];
      case FindVarData(arg)^.VType of
        varSmallint,
        varShortInt,
        varInteger:
          Result := encodeArg(Integer(arg));
        varByte,
        varWord,
        varUInt32:
          Result := encodeArg(Cardinal(arg));
        varInt64:
          Result := encodeArg(Int64(arg));
        varUInt64:
          Result := encodeArg(UInt64(arg));
        varOleStr,
        varStrArg,
        varUStrArg,
        varString,
        varUString:
          Result := encodeArg(string(arg));
        varBoolean:
          Result := encodeArg(Boolean(arg));
        varUnknown:
          if Supports(arg, IContractStruct, struct) then
            Result := encodeArg(tuple(struct.Tuple));
      else
        if VarIsArray(arg) then // tuple
        begin
          offset  := varArrayCount(arg) * 32;
          for idx := VarArrayLowBound(arg, 1) to VarArrayHighBound(arg, 1) do
          begin
            elem := VarArrayGet(arg, [idx]);
            curr := encodeArg(elem);
            if isDynamic(elem) then
            begin
              Result := Result + encodeArg(offset);
              suffix := suffix + curr;
              offset := offset + Length(curr);
            end
            else
              Result := Result + curr;
          end;
          Result := Result + suffix;
        end;
      end;
    end;

    function encodeArg(const arg: TVarRec): TBytes; overload;
    var
      elem  : Variant;
      curr  : TBytes;
      suffix: TBytes;
      offset: Integer;
      struct: IContractStruct;
    begin
      case arg.VType of
        vtBoolean:
          Result := encodeArg(arg.VBoolean);
        vtInteger:
          Result := encodeArg(arg.VInteger);
        vtString:
          Result := encodeArg(UnicodeString(PShortString(arg.VAnsiString)^));
        vtWideString:
          Result := encodeArg(WideString(arg.VWideString^));
        vtInt64:
          Result := encodeArg(arg.VInt64^);
        vtUnicodeString:
          Result := encodeArg(string(arg.VUnicodeString));
        vtVariant:
          Result := encodeArg(arg.VVariant^);
        vtInterface:
          if Supports(IInterface(arg.VInterface), IContractStruct, struct) then
            Result := encodeArg(tuple(struct.Tuple));
        vtObject:
          if arg.VObject is TContractArray then // array
          begin
            Result := encodeArg((arg.VObject as TContractArray).Count);
            offset := (arg.VObject as TContractArray).Count * 32;
            for elem in arg.VObject as TContractArray do
            begin
              curr := encodeArg(elem);
              if isDynamic(elem) then
              begin
                Result := Result + encodeArg(offset);
                suffix := suffix + curr;
                offset := offset + Length(curr);
              end
              else
                Result := Result + curr;
            end;
            Result := Result + suffix;
          end;
      end;
    end;

    function isDynamic(const arg: TVarRec): Boolean; overload;
    begin
      Result := False;
      case arg.VType of
        vtVariant:
          Result := isDynamic(arg.VVariant^);
        vtObject:
          Result := arg.VObject is TContractArray;
        vtInterface:
        begin
          var struct: IContractStruct;
          if Supports(IInterface(arg.VInterface), IContractStruct, struct) then
            Result := isDynamic(tuple(struct.Tuple));
        end;
        vtString, vtWideString, vtUnicodeString:
        begin
          var S: string;
          case arg.VType of
            vtString:
              S := UnicodeString(PShortString(arg.VAnsiString)^);
            vtWideString:
              S := WideString(arg.VWideString^);
            vtUnicodeString:
              S := string(arg.VUnicodeString);
          end;
          Result := Copy(S, System.Low(S), 2).ToLower <> '0x';
        end;
      end;
    end;

    function len(args: array of const): Integer;

      function len(const arg: TVarRec): Integer;
      begin
        Result := 1;
        if arg.VType = vtInterface then
        begin
          var S: IContractStruct;
          if Supports(IInterface(arg.VInterface), IContractStruct, S) then
          begin
            var T := tuple(S.Tuple);
            if not isDynamic(T) then Result := varArrayCount(T);
          end;
        end;
      end;

    begin
      Result := 0;
      for var arg in args do Result := Result + len(arg);
    end;

  var
    arg   : TVarRec;
    curr  : TBytes;
    suffix: TBytes;
    offset: Integer;
  begin
    Result := [];
    offset := len(args) * 32;
    for arg in args do
    begin
      curr := encodeArg(arg);
      if isDynamic(arg) then
      begin
        Result := Result + encodeArg(offset);
        suffix := suffix + curr;
        offset := offset + Length(curr);
      end
      else
        Result := Result + curr;
    end;
    Result := Result + suffix;
  end;

begin
  // step #1: encode the args into a byte array
  var data: TBytes;
  try
    data := encodeArgs(args);
  finally
    for var arg in args do
      if (arg.VType = vtObject) and (arg.VObject is TContractArray) then
        arg.VObject.Free;
  end;
  // step #2: the first four bytes specify the function to be called
  var hash := web3.utils.sha3(web3.utils.toHex(func));
  data := Copy(hash, 0, 4) + data;
  // step #3: hex-encode the data
  Result := web3.utils.toHex(data);
end;

end.
