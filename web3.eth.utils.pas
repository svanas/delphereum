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
  web3;

type
  TEthChain = (
    Mainnet,
    Ropsten,
    Rinkeby,
    Kovan
  );

const
  chainId: array[TEthChain] of Integer = (
    1, // Mainnet
    3, // Ropsten
    4, // Rinkeby
    42 // Kovan
  );

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

function fromWei(wei: BigInteger; &unit: TEthUnit): string;
function toWei(input: string; &unit: TEthUnit): BigInteger;

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

function fromWei(wei: BigInteger; &unit: TEthUnit): string;
var
  negative: Boolean;
  base    : BigInteger;
  baseLen : Integer;
  whole   : BigInteger;
  fraction: BigInteger;
begin
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

function toWei(input: string; &unit: TEthUnit): BigInteger;
var
  negative: Boolean;
  base    : BigInteger;
  baseLen : Integer;
  comps   : TArray<string>;
  whole   : BigInteger;
  fraction: BigInteger;
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
  if not fraction.IsZero then
  begin
    while fraction.ToString.Length < baseLen - 1 do
      fraction := BigInteger.Multiply(fraction, 10);
    Result := BigInteger.Add(Result, fraction);
  end;
  if negative then
    Result := BigInteger.Negate(Result);
end;

end.
