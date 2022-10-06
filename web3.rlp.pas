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
  System.Math,
  System.SysUtils,
  System.Variants,
  // web3
  web3,
  web3.utils;

function encode(item: Integer): IResult<TBytes>; overload;
function encode(const item: string): IResult<TBytes>; overload;
function encode(item: TVarRec): IResult<TBytes>; overload;
function encode(items: array of const): IResult<TBytes>; overload;

implementation

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

end.
