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

unit web3.eth.types;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  TAddress    = string[42];
  TPrivateKey = string[64];
  TArg        = array[0..31] of Byte;
  TTuple      = TArray<TArg>;
  TSignature  = string[132];
  TWei        = BigInteger;
  TTxHash     = string[66];

type
  TASyncTuple  = reference to procedure(tup: TTuple; err: Exception);
  TASyncTxHash = reference to procedure(tx: TTxHash; err: Exception);

implementation

end.
