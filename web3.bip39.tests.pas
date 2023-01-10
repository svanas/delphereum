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
    procedure TestCase;
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3.bip32,
  web3.bip39,
  web3.json,
  web3.utils;

{$R 'web3.bip39.tests.res'}

procedure TTests.TestCase;
begin
  const RS = TResourceStream.Create(hInstance, 'BIP39_TEST_VECTORS', RT_RCDATA);
  try
    const buf = (function: TBytes
    begin
      SetLength(Result, RS.Size);
      RS.Read(Result[0], RS.Size);
    end)();
    const vectors = web3.json.unmarshal(TEncoding.UTF8.GetString(buf));
    if Assigned(vectors) then
    try
      const english = web3.json.getPropAsArr(vectors, 'english');
      if Assigned(english) then
        for var vector in english do
        begin
          const entropy  = ((vector as TJsonArray)[0] as TJsonString).Value;
          const mnemonic = ((vector as TJsonArray)[1] as TJsonString).Value;
          Assert.AreEqual(TMnemonic.Create(web3.utils.fromHex(entropy)).ToString(TMnemonic.English), mnemonic);
          const seed = '0x' + ((vector as TJsonArray)[2] as TJsonString).Value;
          Assert.AreEqual(web3.utils.toHex(web3.bip39.seed(mnemonic, 'TREZOR')), seed);
          const bip32_master = ((vector as TJsonArray)[3] as TJsonString).Value;
          Assert.AreEqual(web3.bip32.master(web3.utils.fromHex(seed)).ToString, bip32_master);
        end;
    finally
      vectors.Free;
    end;
  finally
    RS.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
