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
    procedure TestCase1;
    [Test]
    procedure TestCase2;
  end;

implementation

uses
  // web3
  web3,
  web3.eth.crypto,
  web3.eth.types;

procedure TTests.TestCase1;
const
  msg = 'Hello, World!';
  hex = '0xC7327D84F2790F7255E1B6DEB5090788867E4712753D2F9AA1CC2F5CBCB47F9B7A1EFF2875EE59A7C2BA7CF40715C07241CA056F766134F8F14F2EBA72DAFFA11B';
begin
  // sign
  const signature = web3.eth.crypto.sign(TPrivateKey('b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7'), msg);
  Assert.AreEqual(signature.ToHex, hex);
  // recover
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

procedure TTests.TestCase2;
const
  msg = 'You are better than you know!';
  hex = '0xB080B3B050F8D0854DA7AB3971455B0D6641EB579784B5BF75D6779931DEC08A00AEB67008D1015CB64DC804EFD90789B9E595FB70A44FCA1084616B7F0CA26D1C';
begin
  // sign
  const signature = web3.eth.crypto.sign(TPrivateKey('5b9cd58f644091919ea9eb81d03f771c2e5c15a2ad956ab5e51ac74d533232a8'), msg);
  Assert.AreEqual(signature.ToHex, hex);
  // recover
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
          Assert.AreEqual(string(address), '0x03A0Cb9AC8b55e803D1431eA1cF678D864E48084')
        end);
    end);
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
