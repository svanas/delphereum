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
  web3.rlp.encode([
    9,                                                                          // nonce
    toHex(BigInteger.Multiply(20, BigInteger.Pow(10, 9)), [padToEven]),         // gasPrice
    21000,                                                                      // gas(Limit)
    '0x3535353535353535353535353535353535353535',                               // to
    toHex(BigInteger.Pow(10, 18), [padToEven]),                                 // value
    '',                                                                         // data
    1,                                                                          // v
    0,                                                                          // r
    0                                                                           // s
  ]).ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
  .&else(procedure(encoded: TBytes)
  begin
    Assert.AreEqual(web3.utils.toHex(encoded), '0xec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080');
    web3.rlp.decode(encoded)
      .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
      .&else(procedure(decoded: TArray<TItem>)
      begin
        Assert.IsTrue((Length(decoded) = 1) and (decoded[0].DataType = dtList));
        web3.rlp.decode(decoded[0].Bytes)
          .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
          .&else(procedure(decoded: TArray<TItem>)
          begin
            Assert.IsTrue(Length(decoded) = 9);
            Assert.AreEqual(decoded[0].Bytes[0], Byte(9));
            Assert.AreEqual(StrToInt64(web3.utils.toHex('$', decoded[1].Bytes)), Int64(20000000000));
            Assert.AreEqual(StrToInt(web3.utils.toHex('$', decoded[2].Bytes)), Integer(21000));
            Assert.AreEqual(web3.utils.toHex(decoded[3].Bytes), '0x3535353535353535353535353535353535353535');
            Assert.AreEqual(StrToInt64(web3.utils.toHex('$', decoded[4].Bytes)), Int64(1000000000000000000));
          end);
      end);
  end);
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
    web3.rlp.encode(TEST_CASE.input)
      .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
      .&else(procedure(encoded: TBytes)
      begin
        Assert.AreEqual(web3.utils.toHex(encoded), TEST_CASE.output);
        web3.rlp.decode(encoded)
          .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
          .&else(procedure(decoded: TArray<TItem>)
          begin
            if Length(decoded[0].Bytes) = 0 then
              Assert.AreEqual(0, TEST_CASE.input)
            else
              Assert.AreEqual(StrToInt(web3.utils.toHex('$', decoded[0].Bytes)), TEST_CASE.input);
          end);
      end);
  end;
end;

procedure TTests.TestCase3;
begin
  web3.rlp.encode('')
    .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
    .&else(procedure(encoded: TBytes)
    begin
      Assert.AreEqual(toHex(encoded), '0x80');
      web3.rlp.decode(encoded)
        .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
        .&else(procedure(decoded: TArray<TItem>)
        begin
          Assert.IsTrue((Length(decoded) = 1) and (Length(decoded[0].Bytes) = 0) and (decoded[0].DataType = dtString));
        end);
    end);

  web3.rlp.encode([])
    .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
    .&else(procedure(encoded: TBytes)
    begin
      Assert.AreEqual(toHex(encoded), '0xc0');
      web3.rlp.decode(encoded)
        .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
        .&else(procedure(decoded: TArray<TItem>)
        begin
          Assert.IsTrue((Length(decoded) = 1) and (Length(decoded[0].Bytes) = 0) and (decoded[0].DataType = dtList));
        end);
    end);

  web3.rlp.encode(['dog', 'god', 'cat'])
    .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
    .&else(procedure(encoded: TBytes)
    begin
      Assert.AreEqual(toHex(encoded), '0xcc83646f6783676f6483636174');
      web3.rlp.decode(encoded)
        .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
        .&else(procedure(decoded: TArray<TItem>)
        begin
          Assert.IsTrue((Length(decoded) = 1) and (decoded[0].DataType = dtList));
          web3.rlp.decode(decoded[0].Bytes)
            .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
            .&else(procedure(decoded: TArray<TItem>)
            begin
              Assert.AreEqual(TEncoding.UTF8.GetString(decoded[0].Bytes), 'dog');
              Assert.AreEqual(TEncoding.UTF8.GetString(decoded[1].Bytes), 'god');
              Assert.AreEqual(TEncoding.UTF8.GetString(decoded[2].Bytes), 'cat');
            end);
        end);
    end);

  web3.rlp.encode('Lorem ipsum dolor sit amet, consectetur adipisicing elit')
    .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
    .&else(procedure(encoded: TBytes)
    begin
      Assert.AreEqual(toHex(encoded), '0xb8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974');
      web3.rlp.decode(encoded)
        .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
        .&else(procedure(decoded: TArray<TItem>)
        begin
          Assert.AreEqual(TEncoding.UTF8.GetString(decoded[0].Bytes), 'Lorem ipsum dolor sit amet, consectetur adipisicing elit');
        end);
    end);
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
    web3.rlp.encode(toHex(BigInteger.Create(TEST_CASE.bigInt), [padToEven]))
      .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
      .&else(procedure(encoded: TBytes)
      begin
        Assert.AreEqual(toHex(encoded), TEST_CASE.output);
        web3.rlp.decode(encoded)
          .ifErr(procedure(err: IError) begin Assert.Fail(err.Message) end)
          .&else(procedure(decoded: TArray<TItem>)
          begin
            Assert.AreEqual(BigInteger.Create(web3.utils.toHex(decoded[0].Bytes)).ToString, TEST_CASE.bigInt);
          end);
      end);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
