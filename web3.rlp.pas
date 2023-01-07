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

unit web3.rlp;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3;

type
  TDataType = (dtString, dtList);

  TItem = record
    Bytes   : TBytes;
    DataType: TDataType;
    constructor Create(const aBytes: TBytes; aDataType: TDataType);
  end;

function encode(item: Integer): IResult<TBytes>; overload;
function encode(const item: string): IResult<TBytes>; overload;
function encode(item: TVarRec): IResult<TBytes>; overload;
function encode(items: array of const): IResult<TBytes>; overload;
function recode(items: array of TItem): IResult<TBytes>;
function decode(const input: TBytes): IResult<TArray<TItem>>;

implementation

uses
  // Delphi
  System.Math,
  System.Variants,
  // web3
  web3.error,
  web3.utils;

function encodeLength(len, offset: Integer): IResult<TBytes>;

  function toBinary(x: Integer): TBytes;
  begin
    if x = 0 then
      Result := []
    else
    begin
      var i, r: Word;
      DivMod(x, 256, i, r);
      Result := toBinary(i) + [r];
    end;
  end;

begin
  if len < 56 then
    Result := TResult<TBytes>.Ok([len + offset])
  else
    if len < Power(256, 8) then
    begin
      const bin = toBinary(len);
      Result := TResult<TBytes>.Ok([Length(bin) + offset + 55] + bin);
    end
    else
      Result := TResult<TBytes>.Err([], 'RLP input is too long');
end;

function encodeItem(const item: TBytes): IResult<TBytes>; overload;
begin
  const len = Length(item);
  if (len = 1) and (item[0] < $80) then
  begin
    Result := TResult<TBytes>.Ok(item);
    EXIT;
  end;
  Result := encodeLength(len, $80);
  if Result.IsOk then
    Result := TResult<TBytes>.Ok(Result.Value + item);
end;

function encodeItem(const item: Variant): IResult<TBytes>; overload;
begin
  case FindVarData(item)^.VType of
    varEmpty:
      Result := TResult<TBytes>.Ok([]);
    varSmallint,
    varShortInt,
    varInteger:
      Result := encode(Integer(item));
    varOleStr,
    varStrArg,
    varUStrArg,
    varString,
    varUString:
      Result := encode(string(item));
  else
    if VarIsArray(item) then
    begin
      var output: TBytes := [];
      for var I := VarArrayLowBound(item, 1) to VarArrayHighBound(item, 1) do
      begin
        Result := encodeItem(VarArrayGet(item, [I]));
        if Result.IsErr then
          EXIT;
        output := output + Result.Value;
      end;
      Result := encodeLength(Length(output), $c0);
      if Result.IsOk then
        Result := TResult<TBytes>.Ok(Result.Value + output);
    end
    else
      Result := TResult<TBytes>.Err([], 'Cannot RLP-encode item');
  end;
end;

function encode(item: Integer): IResult<TBytes>;
begin
  var arg: TVarRec;
  arg.VType := vtInteger;
  arg.VInteger := item;
  Result := encode(arg);
end;

function encode(const item: string): IResult<TBytes>;
begin
  var arg: TVarRec;
  arg.VType := vtUnicodeString;
  arg.VUnicodeString := Pointer(item);
  Result := encode(arg);
end;

function encode(item: TVarRec): IResult<TBytes>;
begin
  if item.VType = vtVariant then
    Result := encodeItem(item.VVariant^)
  else
    Result := encodeItem(web3.utils.fromHex(web3.utils.toHex(item)));
end;

function encode(items: array of const): IResult<TBytes>;
begin
  var output: TBytes := [];
  for var item in items do
  begin
    Result := encode(item);
    if Result.IsErr then
      EXIT;
    output := output + Result.Value;
  end;
  Result := encodeLength(Length(output), $c0);
  if Result.IsOk then
    Result := TResult<TBytes>.Ok(Result.Value + output);
end;

function recode(items: array of TItem): IResult<TBytes>;
begin
  var output: TBytes := [];
  for var item in items do
  begin
    if item.DataType = dtString then
      Result := encodeItem(item.Bytes)
    else
      if Length(item.Bytes) = 0 then
        Result := encodeItem(VarArrayCreate([0, 0], varVariant))
      else
        Result := TResult<TBytes>.Err([], TNotImplemented.Create);
    if Result.IsErr then
      EXIT;
    output := output + Result.Value;
  end;
  Result := encodeLength(Length(output), $c0);
  if Result.IsOk then
    Result := TResult<TBytes>.Ok(Result.Value + output);
end;

type
  TLength = record
    Offset  : Integer;
    Length  : Integer;
    DataType: TDataType;
    constructor Create(aOffset, aLength: Integer; aDataType: TDataType);
  end;

constructor TLength.Create(aOffset, aLength: Integer; aDataType: TDataType);
begin
  Self.Offset   := aOffset;
  Self.Length   := aLength;
  Self.DataType := aDataType;
end;

function decodeLength(const input: TBytes): IResult<TLength>;

  function toInt(input: TBytes): IResult<Integer>;
  begin
    const len = Length(input);
    if len = 0 then
      Result := TResult<Integer>.Err(0, 'RLP input is null')
    else
      if len = 1 then
        Result := TResult<Integer>.Ok(input[0])
      else
      begin
        const I = toInt(Copy(input, 0, -1));
        if I.IsErr then
          Result := TResult<Integer>.Err(0, I.Error)
        else
          Result := TResult<Integer>.Ok(Copy(input, -1)[0] + I.Value * 256);
      end;
  end;

begin
  var empty: TLength;

  const len = Length(input);
  if len = 0 then
  begin
    Result := TResult<TLength>.Err(empty, 'RLP input is null');
    EXIT;
  end;

  const prefix = input[0];

  // For a single byte whose value is in the [$00, $7F] range, that byte is its own RLP encoding.
  if prefix <= $7F then
  begin
    Result := TResult<TLength>.Ok(TLength.Create(0, 1, dtString));
    EXIT;
  end;

  // If a string is 0-55 bytes long, the RLP encoding consists of a single byte with value $80 plus
  // the length of the string followed by the string. The range of the first byte is thus [$80, $B7].
  if (prefix <= $B7) and (len > prefix - $80) then
  begin
    Result := TResult<TLength>.Ok(TLength.Create(1, prefix - $80, dtString));
    EXIT;
  end;

  // If a string is more than 55 bytes long, the RLP encoding consists of a single byte with value
  // $B7 plus the length of the length of the string in binary form, followed by the length of the
  // string, followed by the string. The range of the first byte is thus [$B8, $BF].
  if prefix <= $BF then
  begin
    const len_of_len = prefix - $B7;
    if len > len_of_len then
    begin
      const len_of_payload = toInt(Copy(input, 1, len_of_len));
      if len_of_payload.IsOk and (len > len_of_len + len_of_payload.Value) then
      begin
        Result := TResult<TLength>.Ok(TLength.Create(1 + len_of_len, len_of_payload.Value, dtString));
        EXIT;
      end;
    end;
  end;

  // If the total payload of a list (i.e. the combined length of all its items) is 0-55 bytes long, the
  // RLP encoding consists of a single byte with value $C0 plus the length of the list followed by the
  // concatenation of the RLP encodings of the items. The range of the first byte is thus [$C0, $F7].
  if (prefix <= $F7) and (len > prefix - $C0) then
  begin
    Result := TResult<TLength>.Ok(TLength.Create(1, prefix - $C0, dtList));
    EXIT;
  end;

  // If the total payload of a list is more than 55 bytes long, the RLP encoding consists of a
  // single byte with value $F7 plus the length of the length of the payload in binary form,
  // followed by the length of the payload, followed by the concatenation of the RLP encodings
  // of the items. The range of the first byte is thus [0xF8, 0xFF].
  if prefix <= $FF then
  begin
    const len_of_len = prefix - $F7;
    if len > len_of_len then
    begin
      const len_of_payload = toInt(Copy(input, 1, len_of_len));
      if len_of_payload.IsOk and (len > len_of_len + len_of_payload.Value) then
      begin
        Result := TResult<TLength>.Ok(TLength.Create(1 + len_of_len, len_of_payload.Value, dtList));
        EXIT;
      end;
    end;
  end;

  Result := TResult<TLength>.Err(empty, 'input does not conform to RLP encoding');
end;

constructor TItem.Create(const aBytes: TBytes; aDataType: TDataType);
begin
  Self.Bytes    := aBytes;
  Self.DataType := aDataType;
end;

function decode(const input: TBytes): IResult<TArray<TItem>>;
begin
  if Length(input) = 0 then
  begin
    Result := TResult<TArray<TItem>>.Ok([]);
    EXIT;
  end;
  const this = decodeLength(input);
  if this.IsErr then
  begin
    Result := TResult<TArray<TItem>>.Err([], this.Error);
    EXIT;
  end;
  var output: TArray<TItem> := [TItem.Create(Copy(input, this.Value.Offset, this.Value.Length), this.Value.DataType)];
  const next = decode(Copy(input, this.Value.offset + this.Value.length));
  if next.IsOk then
    for var I := 0 to High(next.Value) do output := output + [next.Value[I]];
  Result := TResult<TArray<TItem>>.Ok(output);
end;

end.
