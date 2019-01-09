unit web3.eth.utils;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

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

function fromWei(wei: BigInteger; &unit: TEthUnit): string; overload;
function fromWei(wei: BigInteger; &unit: TEthUnit; const aFormatSettings: TFormatSettings): string; overload;

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
