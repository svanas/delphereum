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
  end;

implementation

uses
  // web3
  web3,
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
begin
  for var I := System.Low(ethers) to System.High(ethers) do
    Assert.AreEqual(web3.eth.utils.fromWei(web3.eth.utils.toWei(ethers[I], ether), ether), ethers[I]);
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
