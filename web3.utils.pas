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

unit web3.utils;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  TToHex = set of (padToEven, zeroAs0x0, noPrefix);

function toHex(const buf: TBytes): string; overload;
function toHex(const bytes32: TBytes32): string; overload;
function toHex(const prefix: string; const buf: TBytes): string; overload;
function toHex(const buf: TBytes; offset, len: Integer): string; overload;
function toHex(const prefix: string; const buf: TBytes; offset, len: Integer): string; overload;

function toHex(const str: string): string; overload;
function toHex(const prefix, str: string): string; overload;
function toHex(const str: string; offset, len: Integer): string; overload;
function toHex(const prefix, str: string; offset, len: Integer): string; overload;

function toHex(val: TVarRec): string; overload;
function toHex(int: BigInteger; options: TToHex = []): string; overload;
function toBin(int: BigInteger): string;

function isHex(const str: string): Boolean; overload;
function isHex(const prefix, str: string): Boolean; overload;

function fromHex(hex: string): TBytes;
function fromHex32(hex: string): TBytes32;

function scale(amount: Double; decimals: Byte): BigInteger;
function unscale(amount: BigInteger; decimals: Byte): Double;

function  sha3(const hex: string): TBytes; overload;
function  sha3(const buf: TBytes): TBytes; overload;
procedure sha3(client: IWeb3; const hex: string; callback: TProc<string, IError>); overload;

implementation

uses
  // Delphi
  System.JSON,
  System.Math,
  // HashLib4Pascal
  HlpSHA3,
  // web3
  web3.json;

function toHex(const buf: TBytes): string;
begin
  Result := toHex('0x', buf);
end;

function toHex(const bytes32: TBytes32): string;
begin
  var buf: TBytes;
  SetLength(buf, 32);
  Move(bytes32, buf[0], 32);
  Result := toHex('0x', buf);
end;

function toHex(const prefix: string; const buf: TBytes): string;
begin
  Result := toHex(prefix, buf, 0, Length(buf));
end;

function toHex(const buf: TBytes; offset, len: Integer): string;
begin
  Result := toHex('0x', buf, offset, len);
end;

function toHex(const prefix: string; const buf: TBytes; offset, len: Integer): string;
const
  Digits = '0123456789ABCDEF';
begin
  Result := StringOfChar('0', len * 2);
  try
    for var I := 0 to Length(buf) - 1 do
    begin
      Result[2 * (I + offset) + 1] := Digits[(buf[I] shr 4)  + 1];
      Result[2 * (I + offset) + 2] := Digits[(buf[I] and $F) + 1];
    end;
  finally
    Result := prefix + Result;
  end;
end;

function toHex(const str: string): string;
begin
  Result := toHex('0x', str);
end;

function toHex(const prefix, str: string): string;
begin
  if isHex(prefix, str) then
    Result := str
  else
    Result := toHex(prefix, TEncoding.UTF8.GetBytes(str));
end;

function toHex(const str: string; offset, len: Integer): string;
begin
  Result := toHex('0x', str, offset, len);
end;

function toHex(const prefix, str: string; offset, len: Integer): string;
begin
  Result := toHex(TEncoding.UTF8.GetBytes(str), offset, len);
end;

function toHex(val: TVarRec): string;

  // if the length of the string is not even, then pad with a leading zero.
  function pad(const str: string): string;
  begin
    if str = '0' then
      Result := ''
    else
      if str.Length mod 2 = 0 then
        Result := str
      else
        Result := '0' + str;
  end;

begin
  case val.VType of
    vtInteger:
      Result := '0x' + pad(IntToHex(val.VInteger, 0));
    vtString:
      Result := toHex(UnicodeString(PShortString(val.VAnsiString)^));
    vtWideString:
      Result := toHex(WideString(val.VWideString^));
    vtInt64:
      Result := '0x' + pad(IntToHex(val.VInt64^, 0));
    vtUnicodeString:
      Result := toHex(string(val.VUnicodeString));
  end;
end;

function toHex(int: BigInteger; options: TToHex): string;
begin
  if int.IsZero then
  begin
    if zeroAs0x0 in options then
      Result := '0'
    else
      Result := ''
  end
  else
  begin
    if int.IsNegative then
      Result := (web3.Infinite - int.Abs).ToHexString
    else
      Result := int.ToHexString;
    if padToEven in options then
      if Result.Length mod 2 > 0 then
        Result := '0' + Result; // pad to even
  end;
  if not(noPrefix in options) then
    Result := '0x' + Result;
end;

function toBin(int: BigInteger): string;
begin
  Result := '0b' + int.ToBinaryString;
end;

function isHex(const str: string): Boolean;
begin
  Result := isHex('0x', str);
end;

function isHex(const prefix, str: string): Boolean;
begin
  Result := Length(str) > 1;
  if Result then
  begin
    Result := SameText(Copy(str, System.Low(str), Length(prefix)), prefix);
    if Result then
      for var I := System.Low(str) + Length(prefix) to High(str) do
      begin
        Result := CharInSet(str[I], ['0'..'9', 'a'..'f', 'A'..'F']);
        if not Result then
          EXIT;
      end;
  end;
end;

function fromHex(hex: string): TBytes;
begin
  hex := Trim(hex);
  while Copy(hex, System.Low(hex), 2).ToLower = '0x' do
    Delete(hex, System.Low(hex), 2);
  if hex.Length mod 2 > 0 then
    hex := '0' + hex; // pad to even
  SetLength(Result, Length(hex) div 2);
  for var I := System.Low(hex) to Length(hex) div 2 do
    Result[I - 1] := StrToInt('$' + Copy(hex, (I - 1) * 2 + 1, 2));
end;

function fromHex32(hex: string): TBytes32;
begin
  FillChar(Result, SizeOf(Result), 0);
  var buf := fromHex(hex);
  Move(buf[0], Result[0], Min(Length(buf), SizeOf(Result)));
end;

function scale(amount: Double; decimals: Byte): BigInteger;
begin
  Result := BigInteger.Create(amount * Round(Power(10, decimals)));
end;

function unscale(amount: BigInteger; decimals: Byte): Double;
begin
  Result := amount.AsDouble / Round(Power(10, decimals));
end;

function sha3(const hex: string): TBytes;
begin
  Result := sha3(fromHex(hex));
end;

function sha3(const buf: TBytes): TBytes;
begin
  const keccak256 = TKeccak_256.Create;
  try
    Result := keccak256.ComputeBytes(buf).GetBytes;
  finally
    keccak256.Free;
  end;
end;

procedure sha3(client: IWeb3; const hex: string; callback: TProc<string, IError>);
begin
  client.Call('web3_sha3', [hex], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

end.
