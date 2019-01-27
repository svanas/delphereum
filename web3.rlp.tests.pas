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

implementation

function testCase1: Boolean;
begin
  Result :=
    web3.utils.toHex(
      web3.rlp.encode([
        9,                                                     // nonce
        toHex(BigInteger.Multiply(20, BigInteger.Pow(10, 9))), // gasPrice
        21000,                                                 // gas(Limit)
        '0x3535353535353535353535353535353535353535',          // to
        toHex(BigInteger.Pow(10, 18)),                         // value
        '',                                                    // data
        1,                                                     // v
        0,                                                     // r
        0                                                      // s
      ])
    ).ToLower = '0xec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080';
end;

end.
