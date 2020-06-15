{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.utils;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // HashLib4Pascal
  HlpSHA3,
  // Web3
  web3,
  web3.eth.types,
  web3.json,
  web3.json.rpc;

type
  TToHex = set of (padToEven, zeroAs0x0);

function toHex(const buf: TBytes): string; overload;
function toHex(const prefix: string; const buf: TBytes): string; overload;
function toHex(const buf: TBytes; offset, len: Integer): string; overload;
function toHex(const prefix: string; const buf: TBytes; offset, len: Integer): string; overload;

function toHex(const str: string): string; overload;
function toHex(const prefix, str: string): string; overload;
function toHex(const str: string; offset, len: Integer): string; overload;
function toHex(const prefix, str: string; offset, len: Integer): string; overload;

function toHex(val: TVarRec): string; overload;
function toHex(int: BigInteger; options: TToHex = []): string; overload;

function isHex(const str: string): Boolean; overload;
function isHex(const prefix, str: string): Boolean; overload;
function fromHex(hex: string): TBytes;

function  sha3(const hex: string): TBytes; overload;
function  sha3(const buf: TBytes): TBytes; overload;
procedure sha3(client: TWeb3; const hex: string; callback: TAsyncString); overload;

implementation

function toHex(const buf: TBytes): string;
begin
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
var
  I: Integer;
begin
  Result := StringOfChar('0', len * 2);
  try
    for I := 0 to Length(buf) - 1 do
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
    Result := int.ToHexString;
    if padToEven in options then
      if Result.Length mod 2 > 0 then
        Result := '0' + Result; // pad to even
  end;
  Result := '0x' + Result;
end;

function isHex(const str: string): Boolean;
begin
  Result := isHex('0x', str);
end;

function isHex(const prefix, str: string): Boolean;
var
  I: Integer;
begin
  Result := Length(str) > 1;
  if Result then
  begin
    Result := Copy(str, Low(str), Length(prefix)) = prefix;
    if Result then
      for I := Low(str) + Length(prefix) to High(str) do
      begin
        Result := CharInSet(str[I], ['0'..'9', 'a'..'f', 'A'..'F']);
        if not Result then
          EXIT;
      end;
  end;
end;

function fromHex(hex: string): TBytes;
var
  I: Integer;
begin
  hex := Trim(hex);
  while Copy(hex, Low(hex), 2) = '0x' do
    Delete(hex, Low(hex), 2);
  if hex.Length mod 2 > 0 then
    hex := '0' + hex; // pad to even
  SetLength(Result, Length(hex) div 2);
  for I := Low(hex) to Length(hex) div 2 do
    Result[I - 1] := StrToInt('$' + Copy(hex, (I - 1) * 2 + 1, 2));
end;

function sha3(const hex: string): TBytes;
begin
  Result := sha3(fromHex(hex));
end;

function sha3(const buf: TBytes): TBytes;
var
  keccak256: TKeccak_256;
begin
  keccak256 := TKeccak_256.Create;
  try
    Result := keccak256.ComputeBytes(buf).GetBytes;
  finally
    keccak256.Free;
  end;
end;

procedure sha3(client: TWeb3; const hex: string; callback: TAsyncString);
begin
  web3.json.rpc.send(client.URL, 'web3_sha3', [hex], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

end.
