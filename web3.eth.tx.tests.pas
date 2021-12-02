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

unit web3.eth.tx.tests;

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
    [Test]
    procedure TestCase3;
    [Test]
    procedure TestCase4;
    [Test]
    procedure TestCase5;
    [Test]
    procedure TestCase6;
    [Test]
    procedure TestCase7;
    [Test]
    procedure TestCase8;
  end;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth.tx;

procedure TTests.TestCase1;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionLegacy(
      1,                                                                        // chainId
      9,                                                                        // nonce
      '4646464646464646464646464646464646464646464646464646464646464646',       // from
      '0x3535353535353535353535353535353535353535',                             // to
      1000000000000000000,                                                      // value
      '',                                                                       // data
      20000000000,                                                              // gasPrice
      21000                                                                     // gasLimit
    ).ToLower,
    '0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83'
  );
end;

procedure TTests.TestCase2;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      1559,                                                                     // chainId
      0,                                                                        // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '',                                                                       // to
      10,                                                                       // value
      '',                                                                       // data
      3,                                                                        // maxPriorityFeePerGas
      4,                                                                        // maxFeePerGas
      3500                                                                      // gasLimit
    ).ToLower,
    '0x02f850820617800304820dac800a80c080a0de12484b58bd47130bf9964740b4d68e42bcbbbc39b2eed5b917f0ae66f5e630a01b0d7aa6a810d63c25c115ef217e37023bbe3146b9bb1fe580d004d6432f7f32'
  );
end;

procedure TTests.TestCase3;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      1559,                                                                     // chainId
      2,                                                                        // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '0x1ad91ee08f21be3de0ba2ba6918e714da6b45836',                             // to
      10,                                                                       // value
      '0x1232',                                                                 // data
      3,                                                                        // maxPriorityFeePerGas
      4,                                                                        // maxFeePerGas
      3500                                                                      // gasLimit
    ).ToLower,
    '0x02f866820617020304820dac941ad91ee08f21be3de0ba2ba6918e714da6b458360a821232c080a0d5ee3f01ce51d2b2930b268361be6fe9fc542e09311336d335cc4658d7bd7128a0038501925930d090429373c7855220d33a6cb949ea3bea273edcd540271c59ce'
  );
end;

procedure TTests.TestCase4;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      0,                                                                        // chainId
      0,                                                                        // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '',                                                                       // to
      0,                                                                        // value
      '',                                                                       // data
      0,                                                                        // maxPriorityFeePerGas
      0,                                                                        // maxFeePerGas
      0                                                                         // gasLimit
    ).ToLower,
    '0x02f84c8080808080808080c001a001d4a14026b819394d91fef9336d00d3febed6fbe5d0a993c0d29a3b275c03b6a00cf6961f932346b5e6e5774c063e7a8794cd2dace75464d1fe5f38f3ba744cb5'
  );
end;

procedure TTests.TestCase5;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      2,                                                                        // chainId
      0,                                                                        // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '',                                                                       // to
      10,                                                                       // value
      '',                                                                       // data
      3,                                                                        // maxPriorityFeePerGas
      4,                                                                        // maxFeePerGas
      3500                                                                      // gasLimit
    ).ToLower,
    '0x02f84e02800304820dac800a80c001a046cfe7dde69e52b91eafd3b213e4547d9ff6294a5ad79383bdb347828fe20102a041e5ab79953b91967bf790a138d9c380d856e6d8b783f1c1751bc446610e6cc6'
  );
end;

procedure TTests.TestCase6;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      1559,                                                                     // chainId
      0,                                                                        // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '',                                                                       // to
      0,                                                                        // value
      '0x1232',                                                                 // data
      3,                                                                        // maxPriorityFeePerGas
      0,                                                                        // maxFeePerGas
      3500                                                                      // gasLimit
    ).ToLower,
    '0x02f852820617800380820dac8080821232c001a0ea5637f224ab5b53d4efff652631e42647f3e4a1c539a14864b788c5178ae186a0242e177e38763bf6a0c0c48e9c078814177286367767e09fb362ce49b3577bc3'
  );
end;

procedure TTests.TestCase7;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      1559,                                                                     // chainId
      100,                                                                      // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '0x1ad91ee08f21be3de0ba2ba6918e714da6b45836',                             // to
      10,                                                                       // value
      '0x1232',                                                                 // data
      3,                                                                        // maxPriorityFeePerGas
      4,                                                                        // maxFeePerGas
      3500                                                                      // gasLimit
    ).ToLower,
    '0x02f866820617640304820dac941ad91ee08f21be3de0ba2ba6918e714da6b458360a821232c001a04e731e02022a10b97312998630d3dcaabda660e4a5f53d0fc1ebf4ba0cf8597fa01f4639e24823c565e3ac8e094e6eda571d1691022de83285925f9979b8ad7365'
  );
end;

procedure TTests.TestCase8;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionType2(
      1559,                                                                     // chainId
      2,                                                                        // nonce
      'b5b1870957d373ef0eeffecc6e4812c0fd08f554b37b233526acc331bf1544f7',       // from
      '0x1ad91ee08f21be3de0ba2ba6918e714da6b45836',                             // to
      10,                                                                       // value
      '',                                                                       // data
      3,                                                                        // maxPriorityFeePerGas
      4,                                                                        // maxFeePerGas
      3500                                                                      // gasLimit
    ).ToLower,
    '0x02f864820617020304820dac941ad91ee08f21be3de0ba2ba6918e714da6b458360a80c080a02b7505766dabb65f8ef497955459f9ea43ff4a092153a8acb277321a80b784a8a0276140649dae47bbb8f6d8fdc3e0daddb58bba498aa4e0b8c547d0d8ebdbf9a5'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
