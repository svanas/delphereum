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

unit web3.eth.utils;

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
    tether
  );

function fromWei(wei: TWei; &unit: TEthUnit): string;
function toWei(input: string; &unit: TEthUnit): TWei;

implementation

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

function fromWei(wei: TWei; &unit: TEthUnit): string;
var
  negative: Boolean;
  base    : BigInteger;
  baseLen : Integer;
  whole   : BigInteger;
  fraction: BigInteger;
begin
  Result := '';
  negative := wei.Negative;
  base := UnitToWei[&unit];
  baseLen := UnitToWei[&unit].Length;
  if negative then
    wei := wei.Abs;
  BigInteger.DivMod(wei, base, whole, fraction);
  if not fraction.IsZero then
  begin
    Result := fraction.ToString;
    while Result.Length < baseLen - 1 do
      Result := '0' + Result;
    while (Result.Length > 1) and (Result[High(Result)] = '0') do
      Delete(Result, High(Result), 1);
    Result := '.' + Result;
  end;
  Result := whole.ToString + Result;
  if negative then
    Result := '-' + Result;
end;

function toWei(input: string; &unit: TEthUnit): TWei;
var
  negative: Boolean;
  base    : BigInteger;
  baseLen : Integer;
  comps   : TArray<string>;
  whole   : string;
  fraction: string;
begin
  base := UnitToWei[&unit];
  baseLen := UnitToWei[&unit].Length;
  // is it negative?
  negative := (input.Length > 0) and (input[Low(input)] = '-');
  if negative then
    Delete(input, Low(input), 1);
  if (input = '') or (input = '.') then
    raise EWeb3.CreateFmt('Error while converting %s to wei. Invalid value.', [input]);
  // split it into a whole and fractional part
  comps := input.Split(['.']);
  if Length(comps) > 2 then
    raise EWeb3.CreateFmt('Error while converting %s to wei. Too many decimal points.', [input]);
  whole := comps[0];
  if Length(comps) > 1 then
    fraction := comps[1];
  Result := BigInteger.Multiply(whole, base);
  if fraction.Length > 0 then
  begin
    while fraction.Length < baseLen - 1 do
      fraction := fraction + '0';
    Result := BigInteger.Add(Result, fraction);
  end;
  if negative then
    Result := BigInteger.Negate(Result);
end;

end.
