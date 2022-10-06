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

unit web3.crypto.tests;

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
    procedure PrivateKeyToPublicKey_One;
    [Test]
    procedure PrivateKeyToPublicKey_Two;
  end;

implementation

uses
  // web3
  web3,
  web3.eth.types;

procedure TTests.PrivateKeyToPublicKey_One;
begin
  const privateKey: TPrivateKey = 'F6E38D3232AE5D132C5BF7A01D86A549F21E84A724D546CCAD7537E3997D0E48';
  const address = privateKey.GetAddress;
  if address.IsErr then
    Assert.Fail(address.Error.Message)
  else
    Assert.AreEqual(string(address.Value), '0x8B8f64aE499E2564e97A0D1ADe36F64e3B820Fa1');
end;

procedure TTests.PrivateKeyToPublicKey_Two;
begin
  const privateKey: TPrivateKey = '174510FE593B2B70A521130DB66C14030A3603FBEE8428BA81AAB48899571313';
  const address = privateKey.GetAddress;
  if address.IsErr then
    Assert.Fail(address.Error.Message)
  else
    Assert.AreEqual(string(address.Value), '0x6ab80ed87F31B0fb567a176f7efF72c842812d2d');
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
