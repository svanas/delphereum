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

unit web3.types;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.Net.HttpClient,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  TASyncString     = reference to procedure(const str: string; err: Exception);
  TASyncQuantity   = reference to procedure(qty: BigInteger; err: Exception);
  TASyncBoolean    = reference to procedure(bool: Boolean; err: Exception);
  TASyncResponse   = reference to procedure(resp: IHttpResponse; err: Exception);
  TASyncJsonObject = reference to procedure(obj: TJsonObject; err: Exception);

implementation

end.
