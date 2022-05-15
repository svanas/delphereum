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

  TETH_USD = class(TAggregatorV3)
  public
    constructor Create(aClient: IWeb3); reintroduce;
  end;

procedure ETH_USD(client: IWeb3; callback: TAsyncFloat);

implementation

uses
  // Delphi
  System.Math,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.coincap;

procedure ETH_USD(client: IWeb3; callback: TAsyncFloat);
begin
  var coincap := procedure(callback: TAsyncFloat)
  begin
    web3.coincap.ticker('ethereum', procedure(const ticker: ITicker; err: IError)
    begin
      if Assigned(err) then
      begin
        // if coincap didn't work, try Chainlink on Binance Smart Chain
        TETH_USD.Create(TWeb3.Create(BSC, 'https://bsc-dataseed.binance.org')).Price(callback);
        EXIT;
      end;
      callback(ticker.Price, err);
    end);
  end;

  // Ethereum price feed is available on the following networks only.
  if client.Chain in [
    Ethereum,
    Rinkeby,
    Kovan,
    BSC,
    BSC_test_net,
    Polygon,
    Polygon_test_net,
    Gnosis,
    Fantom,
    Fantom_test_net,
    Arbitrum,
    Arbitrum_test_net,
    Optimism,
    Optimism_test_net] then
  begin
    TETH_USD.Create(client).Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then
        coincap(callback)
      else
        callback(price, err);
    end);
    EXIT;
  end;

  // not on any of the above networks? fall back on api.coincap.io
  coincap(callback);
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
    if tup.Empty then
    begin
      callback(0, TError.Create('latestRoundData() returned 0x'));
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

{ TETH_USD }

constructor TETH_USD.Create(aClient: IWeb3);
begin
  case aClient.Chain of
    Ethereum:
      inherited Create(aClient, '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419');
    Rinkeby:
      inherited Create(aClient, '0x8A753747A1Fa494EC906cE90E9f37563A8AF630e');
    Kovan:
      inherited Create(aClient, '0x9326BFA02ADD2366b30bacB125260Af641031331');
    BSC:
      inherited Create(aClient, '0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e');
    BSC_test_net:
      inherited Create(aClient, '0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7');
    Polygon:
      inherited Create(aClient, '0xF9680D99D6C9589e2a93a78A04A279e509205945');
    Polygon_test_net:
      inherited Create(aClient, '0x0715A7794a1dc8e42615F059dD6e406A6594651A');
    Gnosis:
      inherited Create(aClient, '0xa767f745331D267c7751297D982b050c93985627');
    Fantom:
      inherited Create(aClient, '0x11DdD3d147E5b83D01cee7070027092397d63658');
    Fantom_test_net:
      inherited Create(aClient, '0xB8C458C957a6e6ca7Cc53eD95bEA548c52AFaA24');
    Arbitrum:
      inherited Create(aClient, '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612');
    Arbitrum_test_net:
      inherited Create(aClient, '0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8');
    Optimism:
      inherited Create(aClient, '0x13e3Ee699D1909E989722E753853AE30b17e08c5');
    Optimism_test_net:
      inherited Create(aClient, '0xCb7895bDC70A1a1Dce69b689FD7e43A627475A06');
  end;
end;

end.
