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

unit web3.eth.chainlink;

interface

uses
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.types;

type
  TAggregatorV3 = class(TCustomContract)
  public
    procedure LatestRoundData(callback: TAsyncTuple);
    procedure Decimals(callback: TAsyncQuantity);
    procedure Price(callback: TAsyncFloat);
  end;

  TEthUsd = class(TAggregatorV3)
  public
    constructor Create(aClient: IWeb3); reintroduce;
  end;

procedure eth_usd(client: IWeb3; callback: TAsyncFloat);

implementation

uses
  // Delphi
  System.Math,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.coincap;

procedure eth_usd(client: IWeb3; callback: TAsyncFloat);
var
  EthUsd: TEthUsd;
begin
  // Ethereum price feed is available on Mainnet and Rinkeby and Kovan only.
  if client.Chain in [Mainnet, Rinkeby, Kovan] then
  begin
    EthUsd := TEthUsd.Create(client);
    if Assigned(EthUsd) then
    begin
      EthUsd.Price(procedure(price: Extended; err: IError)
      begin
        try
          callback(price, err);
        finally
          EthUsd.Free;
        end;
      end);
      EXIT;
    end;
  end;
  // Not on Mainnet or Rinkeby or Kovan? Fall back on api.coincap.io
  web3.coincap.ticker('ethereum', procedure(ticker: ITicker; err: IError)
  begin
    callback(ticker.Price, err);
  end);
end;

{ TAggregatorV3 }

procedure TAggregatorV3.LatestRoundData(callback: TAsyncTuple);
begin
  web3.eth.call(Client, Contract, 'latestRoundData()', [], callback);
end;

procedure TAggregatorV3.Decimals(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'decimals()', [], callback);
end;

procedure TAggregatorV3.Price(callback: TAsyncFloat);
begin
  Self.LatestRoundData(procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    Self.Decimals(procedure(decimals: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      callback(tup[1].toInt64 / Power(10, decimals.AsInteger), nil);
    end);
  end);
end;

{ TEthUsd}

constructor TEthUsd.Create(aClient: IWeb3);
begin
  case aClient.Chain of
    Mainnet:
      inherited Create(aClient, '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419');
    Rinkeby:
      inherited Create(aClient, '0x8A753747A1Fa494EC906cE90E9f37563A8AF630e');
    Kovan:
      inherited Create(aClient, '0x9326BFA02ADD2366b30bacB125260Af641031331');
  end;
end;

end.
