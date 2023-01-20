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

unit web3.bip32.tests;

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
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3.bip32,
  web3.json,
  web3.utils;

{$R 'web3.bip32.tests.res'}

procedure TTests.TestCase;
begin
  const RS = TResourceStream.Create(hInstance, 'BIP32_TEST_VECTORS', RT_RCDATA);
  try
    const buf = (function: TBytes
    begin
      SetLength(Result, RS.Size);
      RS.Read(Result[0], RS.Size);
    end)();
    const vectors = web3.json.unmarshal(TEncoding.UTF8.GetString(buf));
    if Assigned(vectors) then
    try
      for var vector in vectors as TJsonArray do
      begin
        const seed = '0x' + web3.json.getPropAsStr(vector, 'seed');
        const master = web3.bip32.master(web3.utils.fromHex(seed));
        const masterPrivKey = web3.json.getPropAsStr(vector, 'privKey');
        Assert.AreEqual(master.ToString, masterPrivKey);
        const masterPubKey = web3.json.getPropAsStr(vector, 'pubKey');
        Assert.AreEqual(master.PublicKey.ToString, masterPubKey);
        const children = web3.json.getPropAsArr(vector, 'children');
        for var child in children do
        begin
          const path = web3.json.getPropAsBigInt(child, 'path');
          const childKey = master.NewChildKey(path.AsCardinal);
          if childKey.IsErr then
          begin
            Assert.Fail(childKey.Error.Message);
            EXIT;
          end;
          const childPrivKey = web3.json.getPropAsStr(child, 'privKey');
          Assert.AreEqual(childKey.Value.ToString, childPrivKey);
          const childPubKey = web3.json.getPropAsStr(child, 'pubKey');
          Assert.AreEqual(childKey.Value.PublicKey.ToString, childPubKey);
        end;
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
