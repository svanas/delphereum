{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{        need tokens to test with?                                             }
{        1. make sure your wallet is set to the relevant testnet               }
{        2. go to https://app.compound.finance                                 }
{        3. click an asset, then withdraw, and there will be a faucet button   }
{                                                                              }
{******************************************************************************}

unit web3.eth.compound;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.logs,
  web3.eth.types,
  web3.utils;

type
  // Global helper functions
  TCompound = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
  public
    class procedure APY(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncFloat); override;
    class procedure Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); override;
    class procedure Balance(
      client  : TWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); override;
    class function Unscale(amount: BigInteger): Extended; override;
    class procedure Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceipt); override;
  end;

  TOnMint = reference to procedure(
    Sender  : TObject;
    Minter  : TAddress;
    Amount  : BigInteger;
    Tokens  : BigInteger);
  TOnRedeem = reference to procedure(
    Sender  : TObject;
    Redeemer: TAddress;
    Amount  : BigInteger;
    Tokens  : BigInteger);

  IcToken = interface(IERC20)
    //------- read from contract -----------------------------------------------
    procedure Underlying(callback: TAsyncAddress);
    //------- write to contract ------------------------------------------------
    procedure Redeem(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
  end;

  TcToken = class abstract(TERC20, IcToken)
  strict private
    FOnMint  : TOnMint;
    FOnRedeem: TOnRedeem;
    procedure SetOnMint(Value: TOnMint);
    procedure SetOnRedeem(Value: TOnRedeem);
  protected
    function  ListenForLatestBlock: Boolean; override;
    procedure OnLatestBlockMined(log: TLog); override;
  public
    constructor Create(aClient: TWeb3); reintroduce; overload; virtual; abstract;
    //------- read from contract -----------------------------------------------
    procedure APY(callback: TAsyncQuantity);
    procedure BalanceOfUnderlying(owner: TAddress; callback: TAsyncQuantity);
    procedure ExchangeRateCurrent(callback: TAsyncQuantity);
    procedure SupplyRatePerBlock(callback: TAsyncQuantity);
    procedure Underlying(callback: TAsyncAddress);
    //------- write to contract ------------------------------------------------
    procedure Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure Redeem(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure RedeemUnderlying(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    //------- https://compound.finance/docs/ctokens#ctoken-events --------------
    property OnMint  : TOnMint   read FOnMint   write SetOnMint;
    property OnRedeem: TOnRedeem read FOnRedeem write SetOnRedeem;
  end;

  TcDAI = class(TcToken)
  public
    constructor Create(aClient: TWeb3); override;
  end;

  TcUSDC = class(TcToken)
  public
    constructor Create(aClient: TWeb3); override;
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

type
  TcTokenClass = class of TcToken;

const
  cTokenClass: array[TReserve] of TcTokenClass = (
    TcDAI,
    TcUSDC
  );

{ TCompound }

// Approve the cToken contract to move your underlying asset.
class procedure TCompound.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  erc20 : TERC20;
  cToken: IcToken;
begin
  cToken := cTokenClass[reserve].Create(client);
  if Assigned(cToken) then
  begin
    cToken.Underlying(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
        callback(nil, err)
      else
      begin
        erc20 := TERC20.Create(client, addr);
        if Assigned(erc20) then
        try
          erc20.Approve(from, cToken.Contract, amount, callback);
        finally
          erc20.Free;
        end;
      end;
    end);
  end;
end;

// Returns the annual yield as a percentage with 4 decimals.
class procedure TCompound.APY(client: TWeb3; reserve: TReserve; callback: TAsyncFloat);
var
  cToken: TcToken;
begin
  cToken := cTokenClass[reserve].Create(client);
  try
    cToken.APY(procedure(value: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(BigInteger.Divide(value, BigInteger.Create(1e12)).AsInt64 / 1e4, nil);
    end);
  finally
    cToken.Free;
  end;
end;

// Deposits an underlying asset into the lending pool.
class procedure TCompound.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  cToken: TcToken;
begin
  // Before supplying an asset, we must first approve the cToken.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    cToken := cTokenClass[reserve].Create(client);
    try
      cToken.Mint(from, amount, callback);
    finally
      cToken.Free;
    end;
  end);
end;

// Returns how much underlying assets you are entitled to.
class procedure TCompound.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
var
  cToken: TcToken;
begin
  cToken := cTokenClass[reserve].Create(client);
  try
    cToken.BalanceOfUnderlying(owner, callback);
  finally
    cToken.Free;
  end;
end;

class function TCompound.Unscale(amount: BigInteger): Extended;
begin
  Result := BigInteger.Divide(amount, BigInteger.Create(1e10)).AsInt64 / 1e8;
end;

// Redeems your balance of cTokens for the underlying asset.
class procedure TCompound.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceipt);
var
  cToken: IcToken;
begin
  cToken := cTokenClass[reserve].Create(client);
  if Assigned(cToken) then
  begin
    cToken.BalanceOf(from.Address, procedure(amount: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, err)
      else
        cToken.Redeem(from, amount, callback);
    end);
  end;
end;

{ TcToken }

function TcToken.ListenForLatestBlock: Boolean;
begin
  Result := inherited ListenForLatestBlock
         or Assigned(FOnMint) or Assigned(FOnRedeem);
end;

procedure TcToken.OnLatestBlockMined(log: TLog);
begin
  inherited OnLatestBlockMined(log);

  if Assigned(FOnMint) then
    if log.isEvent('Mint(address,uint256,uint256)') then
      // emitted upon a successful Mint
      FOnMint(Self,
              TAddress.New(log.Topic[1]),
              log.Data[0].toBigInt,
              log.Data[1].toBigInt);

  if Assigned(FOnRedeem) then
    if log.isEvent('Redeem(address,uint256,uint256)') then
      // emitted upon a successful Redeem
      FOnRedeem(Self,
                TAddress.New(log.Topic[1]),
                log.Data[0].toBigInt,
                log.Data[1].toBigInt);
end;

procedure TcToken.SetOnMint(Value: TOnMint);
begin
  FOnMint := Value;
  EventChanged;
end;

procedure TcToken.SetOnRedeem(Value: TOnRedeem);
begin
  FOnRedeem := Value;
  EventChanged;
end;

// returns the annual percentage yield for this cToken, scaled by 1e18
procedure TcToken.APY(callback: TAsyncQuantity);
begin
  SupplyRatePerBlock(procedure(qty: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(
        BigInteger.Create(
          (((qty.AsInt64 / 1e18) * (BLOCKS_PER_DAY + 1)) * (365 - 1)) * 1e18
        ),
        nil
      );
  end);
end;

// returns how much underlying ERC20 tokens your cToken balance entitles you to.
procedure TcToken.BalanceOfUnderlying(owner: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'balanceOfUnderlying(address)', [owner], callback);
end;

// returns the current exchange rate of cToken to underlying ERC20 token, scaled by 1e18
// please note that the exchange rate of underlying to cToken increases over time.
procedure TcToken.ExchangeRateCurrent(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'exchangeRateCurrent()', [], procedure(qty: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(qty, nil);
  end);
end;

// supply ERC20 tokens to the protocol, and receive interest earning cTokens back.
// the cTokens are transferred to the wallet of the supplier.
// please note you needs to first call the approve function on the underlying token's contract.
// returns a receipt on success, otherwise https://compound.finance/docs/ctokens#ctoken-error-codes
procedure TcToken.Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract,
    'mint(uint256)', [web3.utils.toHex(amount)],
    300000, // https://compound.finance/docs#gas-costs
    callback);
end;

// redeems specified amount of cTokens in exchange for the underlying ERC20 tokens.
// the ERC20 tokens are transferred to the wallet of the supplier.
// returns a receipt on success, otherwise https://compound.finance/docs/ctokens#ctoken-error-codes
procedure TcToken.Redeem(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(
    Client, from, Contract,
    'redeem(uint256)', [web3.utils.toHex(amount)],
    300000, // https://compound.finance/docs#gas-costs
    callback);
end;

// redeems cTokens in exchange for the specified amount of underlying ERC20 tokens.
// the ERC20 tokens are transferred to the wallet of the supplier.
// returns a receipt on success, otherwise https://compound.finance/docs/ctokens#ctoken-error-codes
procedure TcToken.RedeemUnderlying(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(
    Client, from, Contract,
    'redeemUnderlying(uint256)', [web3.utils.toHex(amount)],
    300000, // https://compound.finance/docs#gas-costs
    callback);
end;

// returns the current per-block supply interest rate for this cToken, scaled by 1e18
procedure TcToken.SupplyRatePerBlock(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'supplyRatePerBlock()', [], procedure(qty: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(qty, nil);
  end);
end;

// Returns the underlying asset contract address for this cToken.
procedure TcToken.Underlying(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'underlying()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TAddress.New(hex), nil)
  end);
end;

{ TcDAI }

constructor TcDAI.Create(aClient: TWeb3);
begin
  // https://compound.finance/docs#networks
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

{ TcUSDC }

constructor TcUSDC.Create(aClient: TWeb3);
begin
  // https://compound.finance/docs#networks
  case aClient.Chain of
    Mainnet, Ganache:
      inherited Create(aClient, '0x39aa39c021dfbae8fac545936693ac917d5e7563');
    Ropsten:
      inherited Create(aClient, '0x20572e4c090f15667cf7378e16fad2ea0e2f3eff');
    Rinkeby:
      inherited Create(aClient, '0x5b281a6dda0b271e91ae35de655ad301c976edb1');
    Goerli:
      inherited Create(aClient, '0xcec4a43ebb02f9b80916f1c718338169d6d5c1f0');
    Kovan:
      inherited Create(aClient, '0xcfc9bb230f00bffdb560fce2428b4e05f3442e35');
  end;
end;

end.
