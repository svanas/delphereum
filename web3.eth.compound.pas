{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
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
  // Delphi
  System.SysUtils,
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
  TCompound = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client  : IWeb3;
      reserve : TReserve;
      _period : TPeriod;
      callback: TProc<Double, IError>); override;
    class procedure Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>); override;
    class procedure Balance(
      client  : IWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TProc<BigInteger, IError>); override;
    class procedure Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TProc<ITxReceipt, BigInteger, IError>); override;
    class procedure WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, BigInteger, IError>); override;
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

  TcToken = class abstract(TERC20)
  strict private
    FOnMint  : TOnMint;
    FOnRedeem: TOnRedeem;
    procedure SetOnMint(Value: TOnMint);
    procedure SetOnRedeem(Value: TOnRedeem);
  protected
    function  ListenForLatestBlock: Boolean; override;
    procedure OnLatestBlockMined(log: PLog; err: IError); override;
  public
    constructor Create(aClient: IWeb3); reintroduce; overload; virtual; abstract;
    //------- read from contract -----------------------------------------------
    procedure APY(callback: TProc<BigInteger, IError>);
    procedure BalanceOfUnderlying(owner: TAddress; callback: TProc<BigInteger, IError>);
    procedure ExchangeRateCurrent(callback: TProc<BigInteger, IError>);
    procedure SupplyRatePerBlock(callback: TProc<BigInteger, IError>);
    procedure Underlying(callback: TProc<TAddress, IError>);
    //------- write to contract ------------------------------------------------
    procedure Mint(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
    procedure Redeem(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
    procedure RedeemUnderlying(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
    //------- https://compound.finance/docs/ctokens#ctoken-events --------------
    property OnMint  : TOnMint   read FOnMint   write SetOnMint;
    property OnRedeem: TOnRedeem read FOnRedeem write SetOnRedeem;
  end;

  TcDAI = class(TcToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TcUSDC = class(TcToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TcUSDT = class(TcToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TcTUSD = class(TcToken)
  public
    constructor Create(aClient: IWeb3); override;
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
    TcUSDC,
    TcUSDT,
    TcTUSD,
    nil
  );

{ TCompound }

// Approve the cToken contract to move your underlying asset.
class procedure TCompound.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const cToken = cTokenClass[reserve].Create(client);
  if Assigned(cToken) then
  begin
    cToken.Underlying(procedure(addr: TAddress; err: IError)
    begin
      try
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        const erc20 = TERC20.Create(client, addr);
        if Assigned(erc20) then
        begin
          erc20.ApproveEx(from, cToken.Contract, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            try
              callback(rcpt, err);
            finally
              erc20.Free;
            end;
          end);
        end;
      finally
        cToken.Free;
      end;
    end);
  end;
end;

class function TCompound.Name: string;
begin
  Result := 'Compound';
end;

class function TCompound.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (
    (reserve in [USDT, TUSD]) and (chain = Ethereum)
  ) or (
    (reserve in [DAI, USDC]) and ((chain = Ethereum) or (chain = Goerli))
  );
end;

// Returns the annual yield as a percentage with 4 decimals.
class procedure TCompound.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TProc<Double, IError>);
begin
  const cToken = cTokenClass[reserve].Create(client);
  if Assigned(cToken) then
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
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  // Before supplying an asset, we must first approve the cToken.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const cToken = cTokenClass[reserve].Create(client);
    if Assigned(cToken) then
    try
      cToken.Mint(from, amount, callback);
    finally
      cToken.Free;
    end;
  end);
end;

// Returns how much underlying assets you are entitled to.
class procedure TCompound.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TProc<BigInteger, IError>);
begin
  const cToken = cTokenClass[reserve].Create(client);
  if Assigned(cToken) then
  try
    cToken.BalanceOfUnderlying(owner, callback);
  finally
    cToken.Free;
  end;
end;

// Redeems your balance of cTokens for the underlying asset.
class procedure TCompound.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const owner = from.GetAddress;
  if owner.IsErr then
  begin
    callback(nil, 0, owner.Error);
    EXIT;
  end;
  Balance(client, owner.Value, reserve, procedure(underlyingAmount: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    const cToken = cTokenClass[reserve].Create(client);
    if Assigned(cToken) then
    begin
      cToken.BalanceOf(owner.Value, procedure(cTokenAmount: BigInteger; err: IError)
      begin
        try
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          cToken.Redeem(from, cTokenAmount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
              callback(nil, 0, err)
            else
              callback(rcpt, underlyingAmount, err);
          end);
        finally
          cToken.Free;
        end;
      end);
    end;
  end);
end;

class procedure TCompound.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const cToken = cTokenClass[reserve].Create(client);
  if Assigned(cToken) then
  try
    cToken.RedeemUnderlying(from, amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        callback(rcpt, amount, err);
    end);
  finally
    cToken.Free;
  end;
end;

{ TcToken }

function TcToken.ListenForLatestBlock: Boolean;
begin
  Result := inherited ListenForLatestBlock
         or Assigned(FOnMint) or Assigned(FOnRedeem);
end;

procedure TcToken.OnLatestBlockMined(log: PLog; err: IError);
begin
  inherited OnLatestBlockMined(log, err);

  if not Assigned(log) then
    EXIT;

  if Assigned(FOnMint) then
    if log^.isEvent('Mint(address,uint256,uint256)') then
      // emitted upon a successful Mint
      FOnMint(Self,
              log^.Topic[1].toAddress, // minter
              log^.Data[0].toUInt256,  // amount
              log^.Data[1].toUInt256); // tokens

  if Assigned(FOnRedeem) then
    if log^.isEvent('Redeem(address,uint256,uint256)') then
      // emitted upon a successful Redeem
      FOnRedeem(Self,
                log^.Topic[1].toAddress, // redeemer
                log^.Data[0].toUInt256,  // amount
                log^.Data[1].toUInt256); // tokens
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
procedure TcToken.APY(callback: TProc<BigInteger, IError>);
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
procedure TcToken.BalanceOfUnderlying(owner: TAddress; callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'balanceOfUnderlying(address)', [owner], callback);
end;

// returns the current exchange rate of cToken to underlying ERC20 token, scaled by 1e18
// please note that the exchange rate of underlying to cToken increases over time.
procedure TcToken.ExchangeRateCurrent(callback: TProc<BigInteger, IError>);
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
procedure TcToken.Mint(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract,
    'mint(uint256)', [web3.utils.toHex(amount)], callback);
end;

// redeems specified amount of cTokens in exchange for the underlying ERC20 tokens.
// the ERC20 tokens are transferred to the wallet of the supplier.
// returns a receipt on success, otherwise https://compound.finance/docs/ctokens#ctoken-error-codes
procedure TcToken.Redeem(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(
    Client, from, Contract,
    'redeem(uint256)', [web3.utils.toHex(amount)], callback);
end;

// redeems cTokens in exchange for the specified amount of underlying ERC20 tokens.
// the ERC20 tokens are transferred to the wallet of the supplier.
// returns a receipt on success, otherwise https://compound.finance/docs/ctokens#ctoken-error-codes
procedure TcToken.RedeemUnderlying(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(
    Client, from, Contract,
    'redeemUnderlying(uint256)', [web3.utils.toHex(amount)], callback);
end;

// returns the current per-block supply interest rate for this cToken, scaled by 1e18
procedure TcToken.SupplyRatePerBlock(callback: TProc<BigInteger, IError>);
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
procedure TcToken.Underlying(callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'underlying()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

{ TcDAI }

constructor TcDAI.Create(aClient: IWeb3);
begin
  // https://compound.finance/docs#networks
  if aClient.Chain = Goerli then
    inherited Create(aClient, '0x822397d9a55d0fefd20f5c4bcab33c5f65bd28eb')
  else
    inherited Create(aClient, '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643');
end;

{ TcUSDC }

constructor TcUSDC.Create(aClient: IWeb3);
begin
  // https://compound.finance/docs#networks
  if aClient.Chain = Goerli then
    inherited Create(aClient, '0xcec4a43ebb02f9b80916f1c718338169d6d5c1f0')
  else
    inherited Create(aClient, '0x39aa39c021dfbae8fac545936693ac917d5e7563');
end;

{ TcUSDT }

constructor TcUSDT.Create(aClient: IWeb3);
begin
  // https://compound.finance/docs#networks
  inherited Create(aClient, '0xf650c3d88d12db855b8bf7d11be6c55a4e07dcc9');
end;

{ TcTUSD }

constructor TcTUSD.Create(aClient: IWeb3);
begin
  // https://compound.finance/docs#networks
  inherited Create(aClient, '0x12392f67bdf24fae0af363c24ac620a2f67dad86');
end;

end.
