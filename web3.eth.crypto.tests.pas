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

unit web3.eth.crypto.tests;

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
    procedure Sign;
    [Test]
    procedure Recover;
  end;

implementation

uses
  // web3
  web3,
  web3.eth.crypto;

const
  msg = 'Hello, World!';
  hex = '0xC7327D84F2790F7255E1B6DEB5090788867E4712753D2F9AA1CC2F5CBCB47F9B7A1EFF2875EE59A7C2BA7CF40715C07241CA056F766134F8F14F2EBA72DAFFA11B';

procedure TTests.Sign;
begin
  const signature = web3.eth.crypto.sign('b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7', msg);
  Assert.AreEqual(signature.ToHex, hex);
end;

procedure TTests.Recover;
begin
  TSignature.FromHex(hex)
    .ifErr(procedure(err: IError)
    begin
      Assert.Fail(err.Message)
    end)
    .&else(procedure(signature: TSignature)
    begin
      web3.eth.crypto.ecrecover(msg, signature)
        .ifErr(procedure(err: IError)
        begin
          Assert.Fail(err.Message)
        end)
        .&else(procedure(address: TAddress)
        begin
          Assert.AreEqual(string(address), '0x12890d2cce102216644c59dae5baed380d84830c')
        end);
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
