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
  ngtv : Boolean;
  base : BigInteger;
  whole: BigInteger;
  frac : BigInteger;
begin
  ngtv := wei.Negative;
  base := UnitToWei[&unit];
  if ngtv then
    wei := wei.Abs;
  BigInteger.DivMod(wei, base, whole, frac);
  Result := whole.ToString;
  if frac > 0 then
    Result := Result + '.' + frac.ToString;
  if ngtv then
    Result := '-' + Result;
end;

function toWei(input: string; &unit: TEthUnit): BigInteger;
var
  ngtv : Boolean;
  base : BigInteger;
  comps: TArray<string>;
  whole: BigInteger;
  frac : BigInteger;
begin
  base := UnitToWei[&unit];
  // is it negative?
  ngtv := (input.Length > 0) and (input[Low(input)] = '-');
  if ngtv then
    Delete(input, Low(input), 1);
  if (input = '') or (input = '.') then
    raise EWeb3.CreateFmt('Error while converting %s to wei. Invalid value.', [input]);
  // split it into a whole and fractional part
  comps := input.Split(['.']);
  if Length(comps) > 2 then
    raise EWeb3.CreateFmt('Error while converting %s to wei. Too many decimal points.', [input]);
  whole := comps[0];
  if Length(comps) > 1 then
    frac := comps[1];
  Result := BigInteger.Multiply(whole, base);
  if frac > 0 then
    Result := BigInteger.Add(Result, frac);
  if ngtv then
    Result := BigInteger.Negate(Result);
end;

end.
