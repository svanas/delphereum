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

unit web3.rlp.tests;

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
  end;

implementation

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.rlp,
  web3.utils;

procedure TTests.TestCase1;
begin
  const encoded = web3.rlp.encode([
    9,                                                                          // nonce
    toHex(BigInteger.Multiply(20, BigInteger.Pow(10, 9)), [padToEven]),         // gasPrice
    21000,                                                                      // gas(Limit)
    '0x3535353535353535353535353535353535353535',                               // to
    toHex(BigInteger.Pow(10, 18), [padToEven]),                                 // value
    '',                                                                         // data
    1,                                                                          // v
    0,                                                                          // r
    0                                                                           // s
  ]);
  if encoded.IsErr then
    Assert.Fail(encoded.Error.Message)
  else
    Assert.AreEqual(
      web3.utils.toHex(encoded.Value),
      '0xec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080'
    );
end;

procedure TTests.TestCase2;
type
  TTestCase = record
    input : Integer;
    output: string;
  end;
const
  TEST_CASES: array[0..7] of TTestCase = (
    (input: 0;      output: '0x80'),
    (input: 1;      output: '0x01'),
    (input: 16;     output: '0x10'),
    (input: 79;     output: '0x4f'),
    (input: 127;    output: '0x7f'),
    (input: 128;    output: '0x8180'),
    (input: 1000;   output: '0x8203e8'),
    (input: 100000; output: '0x830186a0')
  );
begin
  for var TEST_CASE in TEST_CASES do
  begin
    const encoded = web3.rlp.encode(TEST_CASE.input);
    if encoded.IsErr then
      Assert.Fail(encoded.Error.Message)
    else
      Assert.AreEqual(toHex(encoded.Value), TEST_CASE.output);
  end;
end;

procedure TTests.TestCase3;
var
  encoded: IResult<TBytes>;
begin
  encoded := web3.rlp.encode('');
  if encoded.IsErr then
    Assert.Fail(encoded.Error.Message)
  else
    Assert.AreEqual(toHex(encoded.Value), '0x80');

  encoded := web3.rlp.encode([]);
  if encoded.IsErr then
    Assert.Fail(encoded.Error.Message)
  else
    Assert.AreEqual(toHex(encoded.Value), '0xc0');

  encoded := web3.rlp.encode(['dog', 'god', 'cat']);
  if encoded.IsErr then
    Assert.Fail(encoded.Error.Message)
  else
    Assert.AreEqual(toHex(encoded.Value), '0xcc83646f6783676f6483636174');

  encoded := web3.rlp.encode('Lorem ipsum dolor sit amet, consectetur adipisicing elit');
  if encoded.IsErr then
    Assert.Fail(encoded.Error.Message)
  else
    Assert.AreEqual(toHex(encoded.Value), '0xb8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974');
end;

procedure TTests.TestCase4;
type
  TTestCase = record
    bigInt: string;
    output: string;
  end;
const
  TEST_CASES: array[0..2] of TTestCase = (
    (
      bigInt: '83729609699884896815286331701780722';
      output: '0x8f102030405060708090a0b0c0d0e0f2'
    ),(
      bigInt: '105315505618206987246253880190783558935785933862974822347068935681';
      output: '0x9c0100020003000400050006000700080009000a000b000c000d000e01'
    ),(
      bigInt: '115792089237316195423570985008687907853269984665640564039457584007913129639936';
      output: '0xa1010000000000000000000000000000000000000000000000000000000000000000'
    )
  );
begin
  for var TEST_CASE in TEST_CASES do
  begin
    const encoded = web3.rlp.encode(toHex(BigInteger.Create(TEST_CASE.bigInt), [padToEven]));
    if encoded.IsErr then
      Assert.Fail(encoded.Error.Message)
    else
      Assert.AreEqual(toHex(encoded.Value), TEST_CASE.output);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
