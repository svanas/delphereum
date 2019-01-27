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
  // web3
  web3.eth.types,
  web3.eth.utils;

function testCase1: Boolean;
function testCase2: Boolean;
function testCase3: Boolean;

implementation

function testCase1: Boolean;
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

function testCase2: Boolean;
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
  and (web3.eth.utils.toWei('1', kether)   = TWei.Create('1000000000000000000000'))
  and (web3.eth.utils.toWei('1', grand)    = TWei.Create('1000000000000000000000'))
  and (web3.eth.utils.toWei('1', mether)   = TWei.Create('1000000000000000000000000'))
  and (web3.eth.utils.toWei('1', gether)   = TWei.Create('1000000000000000000000000000'))
  and (web3.eth.utils.toWei('1', tether)   = TWei.Create('1000000000000000000000000000000'))
  and (web3.eth.utils.toWei('1', kwei)     = web3.eth.utils.toWei('1',    femtoether))
  and (web3.eth.utils.toWei('1', szabo)    = web3.eth.utils.toWei('1',    microether))
  and (web3.eth.utils.toWei('1', finney)   = web3.eth.utils.toWei('1',    milliether))
  and (web3.eth.utils.toWei('1', milli)    = web3.eth.utils.toWei('1',    milliether))
  and (web3.eth.utils.toWei('1', milli)    = web3.eth.utils.toWei('1000', micro));
end;

function testCase3: Boolean;
const
  ethers: array[0..17] of string = (
    '0',
    '0.1',
    '0.01',
    '0.001',
    '0.0001',
    '0.00001',
    '0.000001',
    '0.0000001',
    '0.00000001',
    '1',
    '1.1',
    '1.01',
    '1.001',
    '1.0001',
    '1.00001',
    '1.000001',
    '1.0000001',
    '1.00000001');
var
  I: Integer;
begin
  for I := Low(ethers) to High(ethers) do
  begin
    Result := web3.eth.utils.fromWei(web3.eth.utils.toWei(ethers[I], ether), ether) = ethers[I];
    if not Result then
      EXIT;
  end;
end;

end.
