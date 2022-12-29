{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2022 Stefan van As <svanas@runbox.com>              }
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

unit web3.bip39.tests;

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
    procedure TestCase0;
    [Test]
    procedure TestCase1;
  end;

implementation

uses
  // web3
  web3.bip39;

procedure TTests.TestCase0;
begin
  const mnemonic = TMnemonic.Create('00000000000000000000000000000000');
  const secret = mnemonic.ToString(TMnemonic.English);
  Assert.AreEqual(secret, 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
end;

procedure TTests.TestCase1;
begin
  const mnemonic = TMnemonic.Create('7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f');
  const secret = mnemonic.ToString(TMnemonic.English);
  Assert.AreEqual(secret, 'legal winner thank year wave sausage worth useful legal winner thank yellow');
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
