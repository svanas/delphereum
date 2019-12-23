{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.rlp.tests;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.rlp,
  web3.utils;

function testCase1: Boolean;
function testCase2: Boolean;
function testCase3: Boolean;
function testCase4: Boolean;

implementation

function testCase1: Boolean;
begin
  Result :=
    web3.utils.toHex(
      web3.rlp.encode([
        9,                                                           // nonce
        toHex(BigInteger.Multiply(20, BigInteger.Pow(10, 9)), True), // gasPrice
        21000,                                                       // gas(Limit)
        '0x3535353535353535353535353535353535353535',                // to
        toHex(BigInteger.Pow(10, 18), True),                         // value
        '',                                                          // data
        1,                                                           // v
        0,                                                           // r
        0                                                            // s
      ])
    ).ToLower = '0xec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080';
end;

function testCase2: Boolean;
begin
  Result :=
      (toHex(web3.rlp.encode(0)).ToLower      = '0x80')
  and (toHex(web3.rlp.encode(1)).ToLower      = '0x01')
  and (toHex(web3.rlp.encode(16)).ToLower     = '0x10')
  and (toHex(web3.rlp.encode(79)).ToLower     = '0x4f')
  and (toHex(web3.rlp.encode(127)).ToLower    = '0x7f')
  and (toHex(web3.rlp.encode(128)).ToLower    = '0x8180')
  and (toHex(web3.rlp.encode(1000)).ToLower   = '0x8203e8')
  and (toHex(web3.rlp.encode(100000)).ToLower = '0x830186a0');
end;

function testCase3: Boolean;
begin
  Result :=
      (toHex(web3.rlp.encode([])).ToLower = '0xc0')
  and (toHex(web3.rlp.encode('')).ToLower = '0x80')
  and (toHex(web3.rlp.encode(['dog', 'god', 'cat'])).ToLower = '0xcc83646f6783676f6483636174')
  and (toHex(web3.rlp.encode('Lorem ipsum dolor sit amet, consectetur adipisicing elit')).ToLower = '0xb8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974');
end;

function testCase4: Boolean;
begin
  Result :=
      (toHex(web3.rlp.encode(toHex(BigInteger.Create('83729609699884896815286331701780722'), True))).ToLower = '0x8f102030405060708090a0b0c0d0e0f2')
  and (toHex(web3.rlp.encode(toHex(BigInteger.Create('105315505618206987246253880190783558935785933862974822347068935681'), True))).ToLower = '0x9c0100020003000400050006000700080009000a000b000c000d000e01')
  and (toHex(web3.rlp.encode(toHex(BigInteger.Create('115792089237316195423570985008687907853269984665640564039457584007913129639936'), True))).ToLower = '0xa1010000000000000000000000000000000000000000000000000000000000000000');
end;

end.
