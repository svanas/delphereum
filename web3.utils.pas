unit web3.utils;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // HashLib4Pascal
  HlpSHA3,
  // Web3
  web3,
  web3.json,
  web3.json.rpc;

type
  TASyncString = reference to procedure(const str: string; err: Exception);

function toHex(const buf: TBytes): string; overload;
function toHex(const buf: TBytes; offset, len: Integer): string; overload;

function toHex(const str: string): string; overload;
function toHex(const str: string; offset, len: Integer): string; overload;

function fromHex(hex: string): TBytes;

function  sha3(const hex: string): TBytes; overload;
function  sha3(const buf: TBytes): TBytes; overload;
procedure sha3(client: TWeb3; const hex: string; callback: TASyncString); overload;

implementation

function toHex(const buf: TBytes): string;
begin
  Result := toHex(buf, 0, Length(buf));
end;

function toHex(const buf: TBytes; offset, len: Integer): string;
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
    Result := '0x' + Result;
  end;
end;

function toHex(const str: string): string;
begin
  Result := toHex(TEncoding.UTF8.GetBytes(str));
end;

function toHex(const str: string; offset, len: Integer): string;
begin
  Result := toHex(TEncoding.UTF8.GetBytes(str), offset, len);
end;

function fromHex(hex: string): TBytes;
var
  I: Integer;
begin
  hex := Trim(hex);
  while Copy(hex, Low(hex), 2) = '0x' do
    Delete(hex, Low(hex), 2);
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

procedure sha3(client: TWeb3; const hex: string; callback: TASyncString);
begin
  web3.json.rpc.Send(client.URL, 'web3_sha3', [hex], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(web3.json.GetPropAsStr(resp, 'result'), nil);
  end);
end;

end.
