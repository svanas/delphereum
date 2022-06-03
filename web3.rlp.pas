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

function encode(item: Integer): TBytes; overload;
function encode(const item: string): TBytes; overload;
function encode(item: TVarRec): TBytes; overload;
function encode(items: array of const): TBytes; overload;

implementation

function encodeLength(len, offset: Integer): TBytes;

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
    Result := [len + offset]
  else
    if len < Power(256, 8) then
    begin
      const bin = toBinary(len);
      Result := [Length(bin) + offset + 55] + bin;
    end
    else
      raise EWeb3.Create('RLP input is too long.');
end;

function encodeItem(const item: TBytes): TBytes; overload;
begin
  const len = Length(item);
  if (len = 1) and (item[0] < $80) then
    Result := item
  else
    Result := encodeLength(len, $80) + item;
end;

function encodeItem(const item: Variant): TBytes; overload;
begin
  Result := [];
  case FindVarData(item)^.VType of
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
      for var I := VarArrayLowBound(item, 1) to VarArrayHighBound(item, 1) do
        Result := Result + encodeItem(VarArrayGet(item, [I]));
      Result := encodeLength(Length(Result), $c0) + Result;
    end;
  end;
end;

function encode(item: Integer): TBytes;
begin
  var arg: TVarRec;
  arg.VType := vtInteger;
  arg.VInteger := item;
  Result := encode(arg);
end;

function encode(const item: string): TBytes;
begin
  var arg: TVarRec;
  arg.VType := vtUnicodeString;
  arg.VUnicodeString := Pointer(item);
  Result := encode(arg);
end;

function encode(item: TVarRec): TBytes;
begin
  if item.VType = vtVariant then
    Result := encodeItem(item.VVariant^)
  else
    Result := encodeItem(web3.utils.fromHex(web3.utils.toHex(item)));
end;

function encode(items: array of const): TBytes;
begin
  Result := [];
  for var item in items do
    Result := Result + encode(item);
  Result := encodeLength(Length(Result), $c0) + Result;
end;

end.
