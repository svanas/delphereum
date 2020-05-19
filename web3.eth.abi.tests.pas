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
function testCase3: Boolean;
function testCase4: Boolean;
function testCase5: Boolean;
function testCase6: Boolean;

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

function testCase3: Boolean;
begin
  Result :=
    web3.eth.abi.encode(
      'sam(bytes,bool,uint256[])',
      ['dave', True, &array([1, 2, 3])]
    ).ToLower = '0xa5643bf2' +
      '0000000000000000000000000000000000000000000000000000000000000060' +
      '0000000000000000000000000000000000000000000000000000000000000001' +
      '00000000000000000000000000000000000000000000000000000000000000a0' +
      '0000000000000000000000000000000000000000000000000000000000000004' +
      '6461766500000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000003' +
      '0000000000000000000000000000000000000000000000000000000000000001' +
      '0000000000000000000000000000000000000000000000000000000000000002' +
      '0000000000000000000000000000000000000000000000000000000000000003';
end;

function testCase4: Boolean;
begin
  Result :=
    web3.eth.abi.encode(
      'sam(uint256,uint32[],bytes)',
      [291, &array([1110, 1929]), 'Hello, world!']
    ).ToLower = '0x8bf36d46' +
      '0000000000000000000000000000000000000000000000000000000000000123' +
      '0000000000000000000000000000000000000000000000000000000000000060' +
      '00000000000000000000000000000000000000000000000000000000000000c0' +
      '0000000000000000000000000000000000000000000000000000000000000002' +
      '0000000000000000000000000000000000000000000000000000000000000456' +
      '0000000000000000000000000000000000000000000000000000000000000789' +
      '000000000000000000000000000000000000000000000000000000000000000d' +
      '48656c6c6f2c20776f726c642100000000000000000000000000000000000000';
end;

function testCase5: Boolean;
begin
  Result :=
    web3.eth.abi.encode(
      'headlong_147(uint96,(uint16,int256))',
      [1123223036891436004, tuple([0, 97701118957406])]
    ).ToLower = '0xe2f6ed8b' +
      '0000000000000000000000000000000000000000000000000f967d66a57313e4' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '000000000000000000000000000000000000000000000000000058dbd07d575e';
end;

function testCase6: Boolean;
begin
  Result :=
    web3.eth.abi.encode(
      'operate(' +
        '(address,uint256)[],' +          // accountOwner, accountNumber
        '(' +
          'uint8,uint256,' +              // actionType, accountId
          '(bool,uint8,uint8,uint256),' + // sign, denomination, reference, value
          'uint256,' +                    // primaryMarketId
          'uint256,' +                    // secondaryMarketId
          'address,' +                    // otherAddress
          'uint256,' +                    // otherAccountId
          'bytes' +                       // arbitrary data
        ')[]' +
      ')',
      [
        &array([
          tuple(['0x742d35Cc6634C0532925a3b844Bc454e4438f44e', 0])
        ]),
        &array([
          tuple([1, 0,
            tuple([False, 0, 0, '0x6D6E499B3301E6968B']),
          3, 0, '0x742d35Cc6634C0532925a3b844Bc454e4438f44e', 0, ''])
        ])
      ]
    ).ToLower = '0xa67a6a45' +
      '0000000000000000000000000000000000000000000000000000000000000040' +
      '00000000000000000000000000000000000000000000000000000000000000a0' +
      '0000000000000000000000000000000000000000000000000000000000000001' +
      '000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000001' +
      '0000000000000000000000000000000000000000000000000000000000000020' +
      '0000000000000000000000000000000000000000000000000000000000000001' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '00000000000000000000000000000000000000000000006d6e499b3301e6968b' +
      '0000000000000000000000000000000000000000000000000000000000000003' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000160' +
      '0000000000000000000000000000000000000000000000000000000000000000' +
      '0000000000000000000000000000000000000000000000000000000000000000';
end;




end.
