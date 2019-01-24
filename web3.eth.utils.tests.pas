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

unit web3.eth.utils.tests;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.eth.utils;

type
  TTestCase = class
    class function fromWei: Boolean;
    class function toWei: Boolean;
  end;

implementation

class function TTestCase.fromWei: Boolean;
begin
  Result :=
      (web3.eth.utils.fromWei(1000000000000000000, wei)    = '1000000000000000000')
  and (web3.eth.utils.fromWei(1000000000000000000, kwei)   = '1000000000000000')
  and (web3.eth.utils.fromWei(1000000000000000000, mwei)   = '1000000000000')
  and (web3.eth.utils.fromWei(1000000000000000000, gwei)   = '1000000000')
  and (web3.eth.utils.fromWei(1000000000000000000, szabo)  = '1000000')
  and (web3.eth.utils.fromWei(1000000000000000000, finney) = '1000')
  and (web3.eth.utils.fromWei(1000000000000000000, ether)  = '1')
  and (web3.eth.utils.fromWei(1000000000000000000, kether) = '0.001')
  and (web3.eth.utils.fromWei(1000000000000000000, grand)  = '0.001')
  and (web3.eth.utils.fromWei(1000000000000000000, mether) = '0.000001')
  and (web3.eth.utils.fromWei(1000000000000000000, gether) = '0.000000001')
  and (web3.eth.utils.fromWei(1000000000000000000, tether) = '0.000000000001');
end;

class function TTestCase.toWei: Boolean;
begin
  Result :=
      (web3.eth.utils.toWei('1', wei)      = 1)
  and (web3.eth.utils.toWei('1', kwei)     = 1000)
  and (web3.eth.utils.toWei('1', babbage)  = 1000)
  and (web3.eth.utils.toWei('1', mwei)     = 1000000)
  and (web3.eth.utils.toWei('1', lovelace) = 1000000)
  and (web3.eth.utils.toWei('1', gwei)     = 1000000000)
  and (web3.eth.utils.toWei('1', shannon)  = 1000000000)
  and (web3.eth.utils.toWei('1', szabo)    = 1000000000000)
  and (web3.eth.utils.toWei('1', finney)   = 1000000000000000)
  and (web3.eth.utils.toWei('1', ether)    = 1000000000000000000)
  and (web3.eth.utils.toWei('1', kether)   = BigInteger.Create('1000000000000000000000'))
  and (web3.eth.utils.toWei('1', grand)    = BigInteger.Create('1000000000000000000000'))
  and (web3.eth.utils.toWei('1', mether)   = BigInteger.Create('1000000000000000000000000'))
  and (web3.eth.utils.toWei('1', gether)   = BigInteger.Create('1000000000000000000000000000'))
  and (web3.eth.utils.toWei('1', tether)   = BigInteger.Create('1000000000000000000000000000000'))
  and (web3.eth.utils.toWei('1', kwei)     = web3.eth.utils.toWei('1',    femtoether))
  and (web3.eth.utils.toWei('1', szabo)    = web3.eth.utils.toWei('1',    microether))
  and (web3.eth.utils.toWei('1', finney)   = web3.eth.utils.toWei('1',    milliether))
  and (web3.eth.utils.toWei('1', milli)    = web3.eth.utils.toWei('1',    milliether))
  and (web3.eth.utils.toWei('1', milli)    = web3.eth.utils.toWei('1000', micro));
end;

end.
