{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.defi;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  TReserve = (DAI, USDC);

type
  TLendingProtocol = class abstract
  public
    // Returns the annual yield as a percentage with 4 decimals.
    class procedure APY(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncFloat); virtual; abstract;
    // Deposits an underlying asset into the lending pool.
    class procedure Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); virtual; abstract;
    // Returns how much underlying assets you are entitled to.
    class procedure Balance(
      client  : TWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); virtual; abstract;
    // Returns balance as floating point with 8 decimals.
    class function Unscale(amount: BigInteger): Extended; virtual; abstract;
    // Withdraws your underlying asset from the lending pool.
    class procedure Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceipt); virtual; abstract;
  end;

type
  TLendingProtocolClass = class of TLendingProtocol;
  TAsyncLendingProtocol = reference to procedure(proto: TLendingProtocolClass; err: IError);

implementation

end.
