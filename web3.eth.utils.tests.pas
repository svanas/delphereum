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

unit web3.eth.utils.tests;

{$I web3.inc}

interface

uses
  // DUnitX
  DUnitX.TestFramework;

type
  [TestFixture]
  TTests = class
  public
    [Test]
    procedure FromWei;
    [Test]
    procedure ToWei;
    [Test]
    procedure WeiToWei;
    [Test]
    procedure ToChecksum;
  end;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth.types,
  web3.eth.utils;

procedure TTests.FromWei;
begin
  Assert.IsTrue(
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
    and (web3.eth.utils.fromWei(1000000000000000000, tether) = '0.000000000001')
  );
end;

procedure TTests.ToWei;
begin
  Assert.IsTrue(
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
    and (web3.eth.utils.toWei('1', milli)    = web3.eth.utils.toWei('1000', micro))
  );
end;

procedure TTests.WeiToWei;
const
  TEST_CASES: array[0..17] of string = (
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
begin
  for var TEST_CASE in TEST_CASES do
    Assert.AreEqual(
      web3.eth.utils.fromWei(web3.eth.utils.toWei(TEST_CASE, ether), ether),
      TEST_CASE
    );
end;

procedure TTests.ToChecksum;
const
  TEST_CASES: array[0..3] of string = (
    '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
    '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
    '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
    '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb'
  );
begin
  for var TEST_CASE in TEST_CASES do
  begin
    Assert.AreEqual(
      string(TAddress.New(TEST_CASE.ToUpper).ToChecksum),
      TEST_CASE,
      False
    );
    Assert.AreEqual(
      string(TAddress.New(TEST_CASE.ToLower).ToChecksum),
      TEST_CASE,
      False
    );
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
