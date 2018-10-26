unit web3.utils;

interface

uses
  // Delphi
  System.SysUtils,
  System.JSON,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // Web3
  web3,
  web3.json,
  web3.json.rpc;

type
  TEthUnit = (
    noether,
    wei,
    kwei,
    babbage,
    femtoether,
    mwei,
    lovelace,
    picoether,
    gwei,
    shannon,
    nanoether,
    nano,
    szabo,
    microether,
    micro,
    finney,
    milliether,
    milli,
    ether,
    kether,
    grand,
    mether,
    gether,
    tether);

type
  TASyncString = reference to procedure(const str: string; err: Exception);

function toHex(const buf: TBytes): string; overload;
function toHex(const buf: TBytes; offset, len: Integer): string; overload;

function toHex(const str: string): string; overload;
function toHex(const str: string; offset, len: Integer): string; overload;

function fromHex(hex: string): TBytes;

procedure sha3(client: TWeb3; const hex: string; callback: TASyncString);

function fromWei(wei: BigInteger; &unit: TEthUnit): string; overload;
function fromWei(wei: BigInteger; &unit: TEthUnit; const aFormatSettings: TFormatSettings): string; overload;

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

const
  UnitToWei: array[TEthUnit] of string = (
    '0',
    '1',
    '1000',
    '1000',
    '1000',
    '1000000',
    '1000000',
    '1000000',
    '1000000000',
    '1000000000',
    '1000000000',
    '1000000000',
    '1000000000000',
    '1000000000000',
    '1000000000000',
    '1000000000000000',
    '1000000000000000',
    '1000000000000000',
    '1000000000000000000',
    '1000000000000000000000',
    '1000000000000000000000',
    '1000000000000000000000000',
    '1000000000000000000000000000',
    '1000000000000000000000000000000');

function fromWei(wei: BigInteger; &unit: TEthUnit): string;
begin
  Result := fromWei(wei, &unit, System.SysUtils.FormatSettings);
end;

function fromWei(wei: BigInteger; &unit: TEthUnit; const aFormatSettings: TFormatSettings): string;
var
  base : BigInteger;
  whole: BigInteger;
  frac : BigInteger;
begin
  base := UnitToWei[&unit];
  BigInteger.DivMod(wei, base, whole, frac);
  Result := whole.ToString;
  if frac > 0 then
    Result := Result + aFormatSettings.DecimalSeparator + frac.ToString;
end;

end.
