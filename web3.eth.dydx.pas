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
{******************************************************************************}

unit web3.eth.dydx;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  System.TypInfo,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.abi,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types,
  web3.utils;

type
  // Global helper functions
  TdYdX = class(TLendingProtocol)
  protected
    class procedure TokenAddress(
      client  : IWeb3;
      reserve : TReserve;
      callback: TProc<TAddress, IError>);
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
  public
    class function Name: string; override;
    class function Supports(
      chain   : TChain;
      reserve : TReserve): Boolean; override;
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

  TSoloTotalPar = record
    Borrow: BigInteger;
    Supply: BigInteger;
  end;

  TSoloIndex = record
    Borrow    : Double;
    Supply    : Double;
    LastUpdate: BigInteger;
  end;

  ISoloMarket = interface
    function Token         : TAddress;      // Contract address of the associated ERC20 token
    function TotalPar      : TSoloTotalPar; // Total aggregated supply and borrow amount of the entire market
    function Index         : TSoloIndex;    // Interest index of the market
    function PriceOracle   : TAddress;      // Contract address of the price oracle for this market
    function InterestSetter: TAddress;      // Contract address of the interest setter for this market
    function MarginPremium : Double;        // Multiplier on the marginRatio for this market
    function SpreadPremium : Double;        // Multiplier on the liquidationSpread for this market
    function IsClosing     : Boolean;       // Whether additional borrows are allowed for this market
  end;

  TSoloActionType = (
    Deposit,   // supply tokens
    Withdraw,  // borrow tokens
    Transfer,  // transfer balance between accounts
    Buy,       // buy an amount of some token (externally)
    Sell,      // sell an amount of some token (externally)
    Trade,     // trade tokens against another account
    Liquidate, // liquidate an undercollateralized or expiring account
    Vaporize,  // use excess tokens to zero-out a completely negative account
    Call       // send arbitrary data to an address
  );

  TSoloDenomination = (
    Wei, // the amount is denominated in wei
    Par  // the amount is denominated in par
  );

  TSoloReference = (
    Delta, // the amount is given as a delta from the current value
    Target // the amount is given as an exact number to end up at
  );

  TSoloMargin = class(TCustomContract)
  private
    class function DeployedAt(chain: TChain): IResult<TAddress>;
  protected
    class function ToBigInt(value: TTuple): IResult<BigInteger>;
  public
    const
      marketId: array[TReserve] of Integer = (
        3,  // DAI
        2,  // USDC
        -1, // USDT
        -1, // mUSD
        -1  // TUSD
      );
    procedure GetAccountWei(owner: TAddress; marketId: Integer; callback: TProc<BigInteger, IError>);
    procedure GetEarningsRate(callback: TProc<Double, IError>);
    procedure GetMarket(marketId: Integer; callback: TProc<ISoloMarket, IError>);
    procedure GetMarketInterestRate(marketId: Integer; callback: TProc<Double, IError>);
    procedure GetMarketSupplyInterestRate(marketId: Integer; callback: TProc<Double, IError>);
    procedure GetMarketUtilization(marketId: Integer; callback: TProc<Double, IError>);
    procedure Operate(
      owner            : TPrivateKey;
      actionType       : TSoloActionType;
      amount           : BigInteger;
      denomination     : TSoloDenomination;
      reference        : TSoloReference;
      primaryMarketId  : Integer;
      secondaryMarketId: Integer;
      otherAddress     : TAddress;
      otherAccountId   : Integer;
      callback         : TProc<ITxReceipt, IError>);
    procedure Deposit(
      owner   : TPrivateKey;
      marketId: Integer;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(
      owner   : TPrivateKey;
      marketId: Integer;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
  end;

implementation

const
  INTEREST_RATE_BASE = 1e18;

{ TdYdX }

// Returns contract address of the associated ERC20 token
class procedure TdYdX.TokenAddress(
  client  : IWeb3;
  reserve : TReserve;
  callback: TProc<TAddress, IError>);
begin
  const solo = TSoloMargin.DeployedAt(client.Chain);
  if solo.IsErr then
  begin
    callback(EMPTY_ADDRESS, solo.Error);
    EXIT;
  end;
  const dYdX = TSoloMargin.Create(client, solo.Value);
  if Assigned(dYdX) then
  try
    dYdX.GetMarket(TSoloMargin.marketId[reserve], procedure(market: ISoloMarket; err: IError)
    begin
      if Assigned(err) then
        callback(EMPTY_ADDRESS, err)
      else
        callback(market.Token, nil);
    end);
  finally
    dYdX.Free;
  end;
end;

// Approve the Solo contract to move your tokens.
class procedure TdYdX.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const solo = TSoloMargin.DeployedAt(client.Chain);
  if solo.IsErr then
  begin
    callback(nil, solo.Error);
    EXIT;
  end;
  TokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const erc20 = TERC20.Create(client, addr);
    if Assigned(erc20) then
    begin
      erc20.ApproveEx(from, solo.Value, amount, procedure(rcpt: ITxReceipt; err: IError)
      begin
        try
          callback(rcpt, err);
        finally
          erc20.Free;
        end;
      end);
    end;
  end);
end;

class function TdYdX.Name: string;
begin
  Result := 'dYdX';
end;

class function TdYdX.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain in [Ethereum, Kovan]) and (reserve in [DAI, USDC]);
end;

// Returns the annual yield as a percentage.
class procedure TdYdX.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TProc<Double, IError>);
const
  SECONDS_PER_YEAR = 31536000;
begin
  const solo = TSoloMargin.DeployedAt(client.Chain);
  if solo.IsErr then
  begin
    callback(0, solo.Error);
    EXIT;
  end;
  const dYdX = TSoloMargin.Create(client, solo.Value);
  if Assigned(dYdX) then
  begin
    dYdX.GetMarketSupplyInterestRate(TSoloMargin.marketId[reserve], procedure(qty: Double; err: IError)
    begin
      try
        if Assigned(err) then
          callback(0, err)
        else
          callback(qty * SECONDS_PER_YEAR * 100, nil);
      finally
        dYdX.Free;
      end;
    end);
  end;
end;

class procedure TdYdX.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const solo = TSoloMargin.DeployedAt(client.Chain);
  if solo.IsErr then
  begin
    callback(nil, solo.Error);
    EXIT;
  end;
  // Before moving tokens, we must first approve the Solo contract.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const dYdX = TSoloMargin.Create(client, solo.Value);
    if Assigned(dYdX) then
    try
      dYdX.Deposit(from, TSoloMargin.marketId[reserve], amount, callback);
    finally
      dYdX.Free;
    end;
  end);
end;

class procedure TdYdX.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TProc<BigInteger, IError>);
begin
  const solo = TSoloMargin.DeployedAt(client.Chain);
  if solo.IsErr then
  begin
    callback(0, solo.Error);
    EXIT;
  end;
  const dYdX = TSoloMargin.Create(client, solo.Value);
  if Assigned(dYdX) then
  try
    dYdX.GetAccountWei(owner, TSoloMargin.marketId[reserve], callback);
  finally
    dYdX.Free;
  end;
end;

class procedure TdYdX.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const owner = from.GetAddress;
  if owner.IsErr then
    callback(nil, 0, owner.Error)
  else
    Balance(client, owner.Value, reserve, procedure(amount: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        WithdrawEx(client, from, reserve, amount, callback);
    end);
end;

class procedure TdYdX.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const solo = TSoloMargin.DeployedAt(client.Chain);
  if solo.IsErr then
  begin
    callback(nil, 0, solo.Error);
    EXIT;
  end;
  const dYdX = TSoloMargin.Create(client, solo.Value);
  if Assigned(dYdX) then
  try
    dYdX.Withdraw(from, TSoloMargin.marketId[reserve], amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        callback(rcpt, amount, err);
    end);
  finally
    dYdX.Free;
  end;
end;

{ TSoloMarket }

type
  TSoloMarket = class(TInterfacedObject, ISoloMarket)
  private
    FTuple: TTuple;
  public
    function Token         : TAddress;
    function TotalPar      : TSoloTotalPar;
    function Index         : TSoloIndex;
    function PriceOracle   : TAddress;
    function InterestSetter: TAddress;
    function MarginPremium : Double;
    function SpreadPremium : Double;
    function IsClosing     : Boolean;
    constructor Create(aTuple: TTuple);
  end;

constructor TSoloMarket.Create(aTuple: TTuple);
begin
  inherited Create;
  FTuple := aTuple;
end;

function TSoloMarket.Token: TAddress;
begin
  Result := FTuple[0].toAddress;
end;

function TSoloMarket.TotalPar: TSoloTotalPar;
begin
  Result.Borrow := FTuple[1].toUInt256;
  Result.Supply := FTuple[2].toUInt256;
end;

function TSoloMarket.Index: TSoloIndex;
begin
  Result.Borrow     := FTuple[3].toInt64 / INTEREST_RATE_BASE;
  Result.Supply     := FTuple[4].toInt64 / INTEREST_RATE_BASE;
  Result.LastUpdate := FTuple[5].toUInt256;
end;

function TSoloMarket.PriceOracle: TAddress;
begin
  Result := FTuple[6].toAddress;
end;

function TSoloMarket.InterestSetter: TAddress;
begin
  Result := FTuple[7].toAddress;
end;

function TSoloMarket.MarginPremium: Double;
begin
  Result := FTuple[8].toInt64 / INTEREST_RATE_BASE;
end;

function TSoloMarket.SpreadPremium: Double;
begin
  Result := FTuple[9].toInt64 / INTEREST_RATE_BASE;
end;

function TSoloMarket.IsClosing: Boolean;
begin
  Result := FTuple[10].toBoolean;
end;

{ TSoloMargin }

class function TSoloMargin.DeployedAt(chain: TChain): IResult<TAddress>;
begin
  if chain = Ethereum then
    Result := TResult<TAddress>.Ok('0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e')
  else
    if chain = Kovan then
      Result := TResult<TAddress>.Ok('0x4EC3570cADaAEE08Ae384779B0f3A45EF85289DE')
    else
      Result := TResult<TAddress>.Err(EMPTY_ADDRESS, TError.Create('dYdX is not deployed on %s', [chain.Name]));
end;

class function TSoloMargin.ToBigInt(value: TTuple): IResult<BigInteger>;
begin
  if Length(value) < 2 then
  begin
    Result := TResult<BigInteger>.Err(0, 'not a valid dYdX integer value');
    EXIT;
  end;
  var output := value[1].toUInt256;
  try
    if (not output.IsZero) and (not value[0].toBoolean) then
      output.Sign := -1;
  finally
    Result := TResult<BigInteger>.Ok(output);
  end;
end;

// Get the token balance for a particular account and market.
procedure TSoloMargin.GetAccountWei(
  owner   : TAddress;
  marketId: Integer;
  callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract,
    'getAccountWei((address,uint256),uint256)', [tuple([owner, 0]), marketId],
    procedure(tup: TTuple; err: IError)
    begin
      if Assigned(err) then
        callback(BigInteger.Zero, err)
      else
        TSoloMargin.ToBigInt(tup).Into(callback);
    end
  );
end;

// Get the global earnings-rate variable that determines what percentage of the
// interest paid by borrowers gets passed-on to suppliers.
procedure TSoloMargin.GetEarningsRate(callback: TProc<Double, IError>);
begin
  web3.eth.call(Client, Contract, 'getEarningsRate()', [], procedure(rate: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(rate.AsInt64 / INTEREST_RATE_BASE, nil);
  end);
end;

// Get basic information about a particular market.
procedure TSoloMargin.GetMarket(marketId: Integer; callback: TProc<ISoloMarket, IError>);
begin
  web3.eth.call(Client, Contract, 'getMarket(uint256)', [marketId], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TSoloMarket.Create(tup), err);
  end);
end;

// Get the current borrower interest rate for a market.
procedure TSoloMargin.GetMarketInterestRate(marketId: Integer; callback: TProc<Double, IError>);
begin
  web3.eth.call(Client, Contract, 'getMarketInterestRate(uint256)', [marketId], procedure(rate: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(rate.AsInt64 / INTEREST_RATE_BASE, nil);
  end);
end;

// https://github.com/dydxprotocol/solo/blob/master/src/modules/Getters.ts#L253
procedure TSoloMargin.GetMarketSupplyInterestRate(marketId: Integer; callback: TProc<Double, IError>);
begin
  GetEarningsRate(procedure(earningsRate: Double; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    GetMarketInterestRate(marketId, procedure(borrowInterestRate: Double; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      GetMarketUtilization(marketId, procedure(utilization: Double; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(borrowInterestRate * earningsRate * utilization, nil);
      end);
    end);
  end);
end;

// https://github.com/dydxprotocol/solo/blob/master/src/modules/Getters.ts#L230
procedure TSoloMargin.GetMarketUtilization(marketId: Integer; callback: TProc<Double, IError>);
begin
  GetMarket(marketId, procedure(market: ISoloMarket; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    const totalSupply = market.TotalPar.Supply.AsDouble * market.Index.Supply;
    const totalBorrow = market.TotalPar.Borrow.AsDouble * market.Index.Borrow;
    callback(totalBorrow / totalSupply, nil);
  end);
end;

// The main entry-point to Solo that allows users and contracts to manage accounts.
procedure TSoloMargin.Operate(
  owner            : TPrivateKey;
  actionType       : TSoloActionType;
  amount           : BigInteger;
  denomination     : TSoloDenomination;
  reference        : TSoloReference;
  primaryMarketId  : Integer;
  secondaryMarketId: Integer;
  otherAddress     : TAddress;
  otherAccountId   : Integer;
  callback         : TProc<ITxReceipt, IError>);
begin
  const sender = owner.GetAddress;
  if sender.IsErr then
  begin
    callback(nil, sender.Error);
    EXIT;
  end;
  web3.eth.write(Client, owner, Contract,
    'operate(' +
      '(address,uint256)[],' +            // accountOwner, accountNumber
      '(' +
        'uint8,uint256,' +                // actionType, accountId
        '(bool,uint8,uint8,uint256),' +   // sign, denomination, reference, value
        'uint256,' +                      // primaryMarketId
        'uint256,' +                      // secondaryMarketId
        'address,' +                      // otherAddress
        'uint256,' +                      // otherAccountId
        'bytes' +                         // arbitrary data
      ')[]' +
    ')',
    [
      &array([tuple([sender.Value, 0])]), // accountOwner, accountNumber
      &array([tuple([actionType, 0,       // actionType, accountId
        tuple([
          not(amount.Negative),           // sign
          denomination,                   // denomination
          reference,                      // reference
          web3.utils.toHex(amount.Abs)    // value
        ]),
        primaryMarketId,
        secondaryMarketId,
        otherAddress,
        otherAccountId,
        '0b0'
      ])])
    ],
    callback
  );
end;

// Moves tokens from an address to Solo.
// Can either repay a borrow or provide additional supply.
procedure TSoloMargin.Deposit(
  owner   : TPrivateKey;
  marketId: Integer;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const address = owner.GetAddress;
  if address.IsErr then
    callback(nil, address.Error)
  else
    Operate(
      owner,                    // owner
      TSoloActionType.Deposit,  // actionType
      amount,                   // amount
      TSoloDenomination.Wei,    // denomination
      TSoloReference.Delta,     // reference
      marketId,                 // primaryMarketId
      0,                        // secondaryMarketId (ignored)
      address.Value,            // otherAddress
      0,                        // otherAccountId (ignored)
      callback);
end;

// Moves tokens from Solo to another address.
// Can either borrow tokens or reduce the amount previously supplied.
procedure TSoloMargin.Withdraw(
  owner   : TPrivateKey;
  marketId: Integer;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  if not(amount.IsZero) then
    amount.Sign := -1;
  const address = owner.GetAddress;
  if address.IsErr then
    callback(nil, address.Error)
  else
    Operate(
      owner,                     // owner
      TSoloActionType.Withdraw,  // actionType
      amount,                    // amount
      TSoloDenomination.Wei,     // denomination
      TSoloReference.Delta,      // reference
      marketId,                  // primaryMarketId
      0,                         // secondaryMarketId (ignored)
      address.Value,             // otherAddress
      0,                         // otherAccountId (ignored)
      callback);
end;

end.
