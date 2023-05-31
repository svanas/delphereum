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
  web3.eth.etherscan,
  web3.eth.types,
  web3.utils;

type
  // Global helper functions
  TdYdX = class(TLendingProtocol)
  protected
    class procedure TokenAddress(
      const client  : IWeb3;
      const reserve : TReserve;
      const callback: TProc<TAddress, IError>);
    class procedure Approve(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
  public
    class function Name: string; override;
    class function Supports(
      const chain   : TChain;
      const reserve : TReserve): Boolean; override;
    class procedure APY(
      const client   : IWeb3;
      const etherscan: IEtherscan;
      const reserve  : TReserve;
      const period   : TPeriod;
      const callback : TProc<Double, IError>); override;
    class procedure Deposit(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>); override;
    class procedure Balance(
      const client  : IWeb3;
      const owner   : TAddress;
      const reserve : TReserve;
      const callback: TProc<BigInteger, IError>); override;
    class procedure Withdraw(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const callback: TProc<ITxReceipt, BigInteger, IError>); override;
    class procedure WithdrawEx(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, BigInteger, IError>); override;
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
    class function DeployedAt(const chain: TChain): IResult<TAddress>;
  protected
    class function ToBigInt(const value: TTuple): IResult<BigInteger>;
  public
    const
      marketId: array[TReserve] of Integer = (
        3,  // DAI
        2,  // USDC
        -1, // USDT
        -1  // TUSD
      );
    procedure GetAccountWei(const owner: TAddress; const marketId: Integer; const callback: TProc<BigInteger, IError>);
    procedure GetEarningsRate(const callback: TProc<Double, IError>);
    procedure GetMarket(const marketId: Integer; const callback: TProc<ISoloMarket, IError>);
    procedure GetMarketInterestRate(const marketId: Integer; const callback: TProc<Double, IError>);
    procedure GetMarketSupplyInterestRate(const marketId: Integer; const callback: TProc<Double, IError>);
    procedure GetMarketUtilization(const marketId: Integer; const callback: TProc<Double, IError>);
    procedure Operate(
      const owner            : TPrivateKey;
      const actionType       : TSoloActionType;
      const amount           : BigInteger;
      const denomination     : TSoloDenomination;
      const reference        : TSoloReference;
      const primaryMarketId  : Integer;
      const secondaryMarketId: Integer;
      const otherAddress     : TAddress;
      const otherAccountId   : Integer;
      const callback         : TProc<ITxReceipt, IError>);
    procedure Deposit(
      const owner   : TPrivateKey;
      const marketId: Integer;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(
      const owner   : TPrivateKey;
      const marketId: Integer;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
  end;

implementation

const
  INTEREST_RATE_BASE = 1e18;

{ TdYdX }

// Returns contract address of the associated ERC20 token
class procedure TdYdX.TokenAddress(
  const client  : IWeb3;
  const reserve : TReserve;
  const callback: TProc<TAddress, IError>);
begin
  TSoloMargin.DeployedAt(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(TAddress.Zero, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      const solo = TSoloMargin.Create(client, address);
      if Assigned(solo) then
      try
        solo.GetMarket(TSoloMargin.marketId[reserve], procedure(market: ISoloMarket; err: IError)
        begin
          if Assigned(err) then
            callback(TAddress.Zero, err)
          else
            callback(market.Token, nil);
        end);
      finally
        solo.Free;
      end;
    end);
end;

// Approve the Solo contract to move your tokens.
class procedure TdYdX.Approve(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  TSoloMargin.DeployedAt(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(solo: TAddress)
    begin
      TokenAddress(client, reserve, procedure(address: TAddress; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          web3.eth.erc20.approve(web3.eth.erc20.create(client, address), from, solo, amount, callback);
      end);
    end);
end;

class function TdYdX.Name: string;
begin
  Result := 'dYdX';
end;

class function TdYdX.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve in [DAI, USDC]);
end;

// Returns the annual yield as a percentage.
class procedure TdYdX.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
const
  SECONDS_PER_YEAR = 31536000;
begin
  TSoloMargin.DeployedAt(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      const solo = TSoloMargin.Create(client, address);
      if Assigned(solo) then
      begin
        solo.GetMarketSupplyInterestRate(TSoloMargin.marketId[reserve], procedure(qty: Double; err: IError)
        begin try
          if Assigned(err) then
            callback(0, err)
          else
            callback(qty * SECONDS_PER_YEAR * 100, nil);
        finally
          solo.Free;
        end; end);
      end;
    end);
end;

class procedure TdYdX.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  TSoloMargin.DeployedAt(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      // Before moving tokens, we must first approve the Solo contract.
      Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        const solo = TSoloMargin.Create(client, address);
        if Assigned(solo) then
        try
          solo.Deposit(from, TSoloMargin.marketId[reserve], amount, callback);
        finally
          solo.Free;
        end;
      end);
    end);
end;

class procedure TdYdX.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  TSoloMargin.DeployedAt(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      const solo = TSoloMargin.Create(client, address);
      if Assigned(solo) then
      try
        solo.GetAccountWei(owner, TSoloMargin.marketId[reserve], callback);
      finally
        solo.Free;
      end;
    end);
end;

class procedure TdYdX.Withdraw(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(owner: TAddress)
    begin
      Balance(client, owner, reserve, procedure(amount: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          WithdrawEx(client, from, reserve, amount, callback);
      end);
    end);
end;

class procedure TdYdX.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  TSoloMargin.DeployedAt(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      const solo = TSoloMargin.Create(client, address);
      if Assigned(solo) then
      try
        solo.Withdraw(from, TSoloMargin.marketId[reserve], amount, procedure(rcpt: ITxReceipt; err: IError)
        begin
          if Assigned(err) then
            callback(nil, 0, err)
          else
            callback(rcpt, amount, err);
        end);
      finally
        solo.Free;
      end;
    end);
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
    constructor Create(const aTuple: TTuple);
  end;

constructor TSoloMarket.Create(const aTuple: TTuple);
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

class function TSoloMargin.DeployedAt(const chain: TChain): IResult<TAddress>;
begin
  if chain = Ethereum then
    Result := TResult<TAddress>.Ok('0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e')
  else
    Result := TResult<TAddress>.Err(TAddress.Zero, TError.Create('dYdX is not deployed on %s', [chain.Name]));
end;

class function TSoloMargin.ToBigInt(const value: TTuple): IResult<BigInteger>;
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
  const owner   : TAddress;
  const marketId: Integer;
  const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'getAccountWei((address,uint256),uint256)', [tuple([owner, 0]), marketId], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      TSoloMargin.ToBigInt(tup).into(callback);
  end);
end;

// Get the global earnings-rate variable that determines what percentage of the
// interest paid by borrowers gets passed-on to suppliers.
procedure TSoloMargin.GetEarningsRate(const callback: TProc<Double, IError>);
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
procedure TSoloMargin.GetMarket(const marketId: Integer; const callback: TProc<ISoloMarket, IError>);
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
procedure TSoloMargin.GetMarketInterestRate(const marketId: Integer; const callback: TProc<Double, IError>);
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
procedure TSoloMargin.GetMarketSupplyInterestRate(const marketId: Integer; const callback: TProc<Double, IError>);
begin
  GetEarningsRate(procedure(earningsRate: Double; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      GetMarketInterestRate(marketId, procedure(borrowInterestRate: Double; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
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
procedure TSoloMargin.GetMarketUtilization(const marketId: Integer; const callback: TProc<Double, IError>);
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
  const owner            : TPrivateKey;
  const actionType       : TSoloActionType;
  const amount           : BigInteger;
  const denomination     : TSoloDenomination;
  const reference        : TSoloReference;
  const primaryMarketId  : Integer;
  const secondaryMarketId: Integer;
  const otherAddress     : TAddress;
  const otherAccountId   : Integer;
  const callback         : TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.write(Client, owner, Contract,
        'operate(' +
          '(address,uint256)[],' +           // accountOwner, accountNumber
          '(' +
            'uint8,uint256,' +               // actionType, accountId
            '(bool,uint8,uint8,uint256),' +  // sign, denomination, reference, value
            'uint256,' +                     // primaryMarketId
            'uint256,' +                     // secondaryMarketId
            'address,' +                     // otherAddress
            'uint256,' +                     // otherAccountId
            'bytes' +                        // arbitrary data
          ')[]' +
        ')',
        [
          &array([tuple([sender, 0])]),      // accountOwner, accountNumber
          &array([tuple([actionType, 0,      // actionType, accountId
            tuple([
              not(amount.Negative),          // sign
              denomination,                  // denomination
              reference,                     // reference
              web3.utils.toHex(amount.Abs)   // value
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
    end);
end;

// Moves tokens from an address to Solo.
// Can either repay a borrow or provide additional supply.
procedure TSoloMargin.Deposit(
  const owner   : TPrivateKey;
  const marketId: Integer;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      Operate(
        owner,                    // owner
        TSoloActionType.Deposit,  // actionType
        amount,                   // amount
        TSoloDenomination.Wei,    // denomination
        TSoloReference.Delta,     // reference
        marketId,                 // primaryMarketId
        0,                        // secondaryMarketId (ignored)
        address,                  // otherAddress
        0,                        // otherAccountId (ignored)
        callback);
      end);
end;

// Moves tokens from Solo to another address.
// Can either borrow tokens or reduce the amount previously supplied.
procedure TSoloMargin.Withdraw(
  const owner   : TPrivateKey;
  const marketId: Integer;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  if not(amount.IsZero) then
    amount.Sign := -1;
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      Operate(
        owner,                     // owner
        TSoloActionType.Withdraw,  // actionType
        amount,                    // amount
        TSoloDenomination.Wei,     // denomination
        TSoloReference.Delta,      // reference
        marketId,                  // primaryMarketId
        0,                         // secondaryMarketId (ignored)
        address,                   // otherAddress
        0,                         // otherAccountId (ignored)
        callback);
    end);
end;

end.
