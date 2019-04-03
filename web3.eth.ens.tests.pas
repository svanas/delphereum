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

unit web3.eth.ens.tests;

{$I web3.inc}

interface

function testCase1: Boolean;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3.eth.ens;

function testCase1: Boolean;
begin
  Result :=
      (web3.eth.ens.namehash('')                = '0x0000000000000000000000000000000000000000000000000000000000000000')
  and (web3.eth.ens.namehash('eth').ToLower     = '0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae')
  and (web3.eth.ens.namehash('foo.eth').ToLower = '0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f');
end;

end.
