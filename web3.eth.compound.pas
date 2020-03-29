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

unit web3.eth.compound;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.types;

type
  TCToken = class(TCustomContract)
  public
    procedure BalanceOf(owner: TAddress; callback: TAsyncQuantity);
    procedure BalanceOfUnderlying(owner: TAddress; callback: TAsyncQuantity);
    procedure ExchangeRateCurrent(callback: TAsyncQuantity);
    procedure Mint(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
    procedure Redeem(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
    procedure RedeemUnderlying(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
    procedure SupplyRatePerBlock(callback: TAsyncQuantity);
  end;

type
  TCDai = class(TCToken)
  public
    constructor Create(aClient: TWeb3); reintroduce;
  end;

const
  NO_ERROR                       = 0;
  UNAUTHORIZED                   = 1;  // The sender is not authorized to perform this action.
  BAD_INPUT                      = 2;  // An invalid argument was supplied by the caller.
  COMPTROLLER_REJECTION          = 3;  // The action would violate the comptroller policy.
  COMPTROLLER_CALCULATION_ERROR  = 4;  // An internal calculation has failed in the comptroller.
  INTEREST_RATE_MODEL_ERROR      = 5;  // The interest rate model returned an invalid value.
  INVALID_ACCOUNT_PAIR           = 6;  // The specified combination of accounts is invalid.
  INVALID_CLOSE_AMOUNT_REQUESTED = 7;  // The amount to liquidate is invalid.
  INVALID_COLLATERAL_FACTOR      = 8;  // The collateral factor is invalid.
  MATH_ERROR                     = 9;  // A math calculation error occurred.
  MARKET_NOT_FRESH               = 10; // Interest has not been properly accrued.
  MARKET_NOT_LISTED              = 11; // The market is not currently listed by its comptroller.
  TOKEN_INSUFFICIENT_ALLOWANCE   = 12; // ERC-20 contract must *allow* Money Market contract to call `transferFrom`. The current allowance is either 0 or less than the requested supply, repayBorrow or liquidate amount.
  TOKEN_INSUFFICIENT_BALANCE     = 13; // Caller does not have sufficient balance in the ERC-20 contract to complete the desired action.
  TOKEN_INSUFFICIENT_CASH        = 14; // The market does not have a sufficient cash balance to complete the transaction. You may attempt this transaction again later.
  TOKEN_TRANSFER_IN_FAILED       = 15; // Failure in ERC-20 when transfering token into the market.
  TOKEN_TRANSFER_OUT_FAILED      = 16; // Failure in ERC-20 when transfering token out of the market.

implementation

{ TCToken }

// returns your wallet's cToken balance.
procedure TCToken.BalanceOf(owner: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'balanceOf(address)', [owner], callback);
end;

// returns how much underlying ERC20 tokens your cToken balance entitles you to.
procedure TCToken.BalanceOfUnderlying(owner: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'balanceOfUnderlying(address)', [owner], callback);
end;

// returns the current exchange rate of cToken to underlying ERC20 token.
// please note that the exchange rate of underlying to cToken increases over time.
procedure TCToken.ExchangeRateCurrent(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'exchangeRateCurrent()', [], procedure(qty: BigInteger; err: Exception)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(BigInteger.Divide(qty, $1e18), nil);
  end);
end;

// supply ERC20 tokens to the protocol, and receive interest earning cTokens back.
// the cTokens are transferred to the wallet of the supplier.
// please note you needs to first call the approve function on the underlying token's contract.
procedure TCToken.Mint(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
begin
  // https://compound.finance/developers#gas-costs
  web3.eth.write(Client, from, Contract, 'mint(uint256)', [amount], 300000, callback);
end;

// redeems specified amount of cTokens in exchange for the underlying ERC20 tokens.
// the ERC20 tokens are transferred to the wallet of the supplier.
procedure TCToken.Redeem(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
begin
  // https://compound.finance/developers#gas-costs
  web3.eth.write(Client, from, Contract, 'redeem(uint256)', [amount], 90000, callback);
end;

// redeems cTokens in exchange for the specified amount of underlying ERC20 tokens.
// the ERC20 tokens are transferred to the wallet of the supplier.
procedure TCToken.RedeemUnderlying(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
begin
  // https://compound.finance/developers#gas-costs
  web3.eth.write(Client, from, Contract, 'redeemUnderlying(uint256)', [amount], 90000, callback);
end;

// returns the current per-block supply interest rate for this cToken.
procedure TCToken.SupplyRatePerBlock(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'supplyRatePerBlock()', [], procedure(qty: BigInteger; err: Exception)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(BigInteger.Divide(qty, $1e18), nil);
  end);
end;

{ TCDai }

constructor TCDai.Create(aClient: TWeb3);
begin
  // https://compound.finance/developers#networks
  case aClient.Chain of
    Mainnet, Ganache:
      inherited Create(aClient, '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643');
    Ropsten:
      inherited Create(aClient, '0x6ce27497a64fffb5517aa4aee908b1e7eb63b9ff');
    Rinkeby:
      inherited Create(aClient, '0x6d7f0754ffeb405d23c51ce938289d4835be3b14');
    Goerli:
      inherited Create(aClient, '0x822397d9a55d0fefd20f5c4bcab33c5f65bd28eb');
    Kovan:
      inherited Create(aClient, '0xe7bc397dbd069fc7d0109c0636d06888bb50668c');
  end;
end;

end.
