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

unit web3.eth.dydx;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.types;

type
  EdYdX = class(EWeb3);

  TSoloTotalPar = record
    Borrow: BigInteger;
    Supply: BigInteger;
  end;

  TSoloIndex = record
    Borrow    : Extended;
    Supply    : Extended;
    LastUpdate: BigInteger;
  end;

  ISoloMarket = interface
    function Token         : TAddress;      // Contract address of the associated ERC20 token
    function TotalPar      : TSoloTotalPar; // Total aggregated supply and borrow amount of the entire market
    function Index         : TSoloIndex;    // Interest index of the market
    function PriceOracle   : TAddress;      // Contract address of the price oracle for this market
    function InterestSetter: TAddress;      // Contract address of the interest setter for this market
    function MarginPremium : Extended;      // Multiplier on the marginRatio for this market
    function SpreadPremium : Extended;      // Multiplier on the liquidationSpread for this market
    function IsClosing     : Boolean;       // Whether additional borrows are allowed for this market
  end;

  TAsyncSoloMarket = reference to procedure(market: ISoloMarket; err: IError);

  ISoloMargin = interface
    procedure GetMarketSupplyInterestRate(marketId: Integer; callback: TAsyncFloat);
  end;

  TSoloMargin = class(TCustomContract, ISoloMargin)
  public
    const
      marketId: array[TReserve] of Integer = (
        3, // DAI
        2  // USDC
      );
    constructor Create(aClient: TWeb3); reintroduce;
    procedure GetEarningsRate(callback: TAsyncFloat);
    procedure GetMarket(marketId: Integer; callback: TAsyncSoloMarket);
    procedure GetMarketInterestRate(marketId: Integer; callback: TAsyncFloat);
    procedure GetMarketSupplyInterestRate(marketId: Integer; callback: TAsyncFloat);
    procedure GetMarketUtilization(marketId: Integer; callback: TAsyncFloat);
  end;

implementation

const
  INTEREST_RATE_BASE = 1e18;

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
    function MarginPremium : Extended;
    function SpreadPremium : Extended;
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
  Result := TAddress.New(FTuple[0]);
end;

function TSoloMarket.TotalPar: TSoloTotalPar;
begin
  Result.Borrow := FTuple[1].toBigInt;
  Result.Supply := FTuple[2].toBigInt;
end;

function TSoloMarket.Index: TSoloIndex;
begin
  Result.Borrow     := FTuple[3].toInt64 / INTEREST_RATE_BASE;
  Result.Supply     := FTuple[4].toInt64 / INTEREST_RATE_BASE;
  Result.LastUpdate := FTuple[5].toBigInt;
end;

function TSoloMarket.PriceOracle: TAddress;
begin
  Result := TAddress.New(FTuple[6]);
end;

function TSoloMarket.InterestSetter: TAddress;
begin
  Result := TAddress.New(FTuple[7]);
end;

function TSoloMarket.MarginPremium: Extended;
begin
  Result := FTuple[8].toInt64 / INTEREST_RATE_BASE;
end;

function TSoloMarket.SpreadPremium: Extended;
begin
  Result := FTuple[9].toInt64 / INTEREST_RATE_BASE;
end;

function TSoloMarket.IsClosing: Boolean;
begin
  Result := FTuple[10].toBool;
end;

{ TSoloMargin }

constructor TSoloMargin.Create(aClient: TWeb3);
begin
  case aClient.Chain of
    Mainnet, Ganache:
      inherited Create(aClient, '0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e');
    Ropsten:
      raise EdYdx.Create('dYdX is not deployed on Ropsten');
    Rinkeby:
      raise EdYdx.Create('dYdX is not deployed on Rinkeby');
    Goerli:
      raise EdYdx.Create('dYdX is not deployed on Goerli');
    Kovan:
      raise EdYdx.Create('dYdX is not deployed on Kovan');
  end;
end;

// Get the global earnings-rate variable that determines what percentage of the
// interest paid by borrowers gets passed-on to suppliers.
procedure TSoloMargin.GetEarningsRate(callback: TAsyncFloat);
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
procedure TSoloMargin.GetMarket(marketId: Integer; callback: TAsyncSoloMarket);
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
procedure TSoloMargin.GetMarketInterestRate(marketId: Integer; callback: TAsyncFloat);
begin
  web3.eth.call(Client, Contract, 'getMarketInterestRate(uint256)', [marketId], procedure(rate: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(rate.AsInt64 / INTEREST_RATE_BASE, nil);
  end);
end;

procedure TSoloMargin.GetMarketSupplyInterestRate(marketId: Integer; callback: TAsyncFloat);
begin
  GetEarningsRate(procedure(earningsRate: Extended; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      GetMarketInterestRate(marketId, procedure(borrowInterestRate: Extended; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          GetMarketUtilization(marketId, procedure(utilization: Extended; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(borrowInterestRate * earningsRate * utilization, nil);
          end);
      end);
  end);
end;

procedure TSoloMargin.GetMarketUtilization(marketId: Integer; callback: TAsyncFloat);
begin
  GetMarket(marketId, procedure(market: ISoloMarket; err: IError)
  var
    totalSupply: Extended;
    totalBorrow: Extended;
  begin
    if Assigned(err) then
      callback(0, err)
    else
    begin
      totalSupply := market.TotalPar.Supply.AsExtended * market.Index.Supply;
      totalBorrow := market.TotalPar.Borrow.AsExtended * market.Index.Borrow;
      callback(totalBorrow / totalSupply, nil);
    end;
  end);
end;

end.
