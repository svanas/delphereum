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
  web3.eth.erc20,
  web3.eth.types;

type
  TReserve = (DAI, USDC, USDT);

  TReserveHelper = record helper for TReserve
    function  Address(chain: TChain): TAddress;
    function  Scale(amount: Extended): BigInteger;
    function  Unscale(amount: BigInteger): Extended;
    procedure Balance(client: TWeb3; owner: TAddress; callback: TAsyncQuantity);
  end;

type
  TLendingProtocol = class abstract
  public
    class function Name: string; virtual; abstract;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; virtual; abstract;
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
    // Withdraws your underlying asset from the lending pool.
    class procedure Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceipt); virtual; abstract;
    class procedure WithdrawEx(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); virtual; abstract;
  end;

  TLendingProtocolClass = class of TLendingProtocol;
  TAsyncLendingProtocol = reference to procedure(proto: TLendingProtocolClass; err: IError);

implementation

uses
  // Delphi
  System.TypInfo;

const
  RESERVE_ADDRESS: array[TReserve] of array[TChain] of TAddress = (
    ( // DAI
      '0x6b175474e89094c44da98b954eedeac495271d0f',  // Mainnet
      '',                                            // Ropsten
      '',                                            // Rinkeby
      '',                                            // Goerli
      '',                                            // Kovan
      '0x6b175474e89094c44da98b954eedeac495271d0f'), // Ganache
    ( // USDC
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',  // Mainnet
      '',                                            // Ropsten
      '',                                            // Rinkeby
      '',                                            // Goerli
      '',                                            // Kovan
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'), // Ganache
    ( // USDT
      '0xdac17f958d2ee523a2206206994597c13d831ec7',  // Mainnet
      '',                                            // Ropsten
      '',                                            // Rinkeby
      '',                                            // Goerli
      '',                                            // Kovan
      '0xdac17f958d2ee523a2206206994597c13d831ec7')  // Ganache
  );

function TReserveHelper.Address(chain: TChain): TAddress;
begin
  Result := RESERVE_ADDRESS[Self][chain];
end;

function TReserveHelper.Scale(amount: Extended): BigInteger;
begin
  case Self of
    DAI : Result := BigInteger.Create(amount * 1e18);
    USDC: Result := BigInteger.Create(amount * 1e6);
    USDT: Result := BigInteger.Create(amount * 1e6);
  else
    raise EWeb3.CreateFmt('%s not implemented', [GetEnumName(TypeInfo(TReserve), Ord(Self))]);
  end;
end;

function TReserveHelper.Unscale(amount: BigInteger): Extended;
begin
  case Self of
    DAI : Result := amount.AsExtended / 1e18;
    USDC: Result := amount.AsExtended / 1e6;
    USDT: Result := amount.AsExtended / 1e6;
  else
    raise EWeb3.CreateFmt('%s not implemented', [GetEnumName(TypeInfo(TReserve), Ord(Self))]);
  end;
end;

procedure TReserveHelper.Balance(client: TWeb3; owner: TAddress; callback: TAsyncQuantity);
var
  erc20: TERC20;
begin
  erc20 := TERC20.Create(client, Address(client.Chain));
  try
    erc20.BalanceOf(owner, callback);
  finally
    erc20.Free;
  end;
end;

end.
