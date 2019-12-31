{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.abi.tests;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3.eth.abi;

function testCase1: Boolean;
function testCase2: Boolean;

implementation

function testCase1: Boolean;
begin
  Result :=
    web3.eth.abi.encode(
      'baz(uint32,bool)',
      [69, True]
    ).ToLower = '0xcdcd77c0' +
      '0000000000000000000000000000000000000000000000000000000000000045' +
      '0000000000000000000000000000000000000000000000000000000000000001';
end;

function testCase2: Boolean;
begin
  Result :=
    web3.eth.abi.encode(
      'sam(bytes,bool,uint256)',
      ['dave', True, 69]
    ).ToLower = '0x2fd6b0a2' +
      '0000000000000000000000000000000000000000000000000000000000000060' +
      '0000000000000000000000000000000000000000000000000000000000000001' +
      '0000000000000000000000000000000000000000000000000000000000000045' +
      '0000000000000000000000000000000000000000000000000000000000000004' +
      '6461766500000000000000000000000000000000000000000000000000000000';
end;

end.
