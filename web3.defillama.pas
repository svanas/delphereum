{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2022 Stefan van As <svanas@runbox.com>              }
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

unit web3.defillama;

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3;

type
  ICoin = interface
    function Symbol  : string; // most common symbol used to identify this asset on an exchange
    function Price   : Double; // volume-weighted price based on real-time market data, translated to USD
    function Decimals: Integer;
  end;

function coin(const chain: TChain; const address: TAddress; const callback: TProc<ICoin, IError>): IAsyncResult; overload;
function coin(const chain: TChain; const address: TAddress; const callback: TProc<TJsonValue, IError>): IAsyncResult; overload;

function price(const chain: TChain; const address: TAddress; const callback: TProc<Double, IError>): IAsyncResult;

implementation

uses
  // web3
  web3.eth.types,
  web3.http,
  web3.json;

type
  TCoin = class(TDeserialized, ICoin)
  public
    function Symbol  : string;
    function Price   : Double;
    function Decimals: Integer;
  end;

function TCoin.Symbol: string;
begin
  Result := getPropAsStr(FJsonValue, 'symbol');
end;

function TCoin.Price: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'price');
end;

function TCoin.Decimals: Integer;
begin
  Result := getPropAsInt(FJsonValue, 'decimals');
end;

function network(chain: TChain): string; inline;
begin
  if chain = Ethereum then
    Result := 'ethereum'
  else if chain = Optimism then
    Result := 'optimism'
  else if chain = RSK then
    Result := 'rsk'
  else if chain = BNB then
    Result := 'bsc'
  else if chain = Gnosis then
    Result := 'xdai'
  else if chain = Polygon then
    Result := 'polygon'
  else if chain = Fantom then
    Result := 'fantom'
  else if chain = Arbitrum then
    Result := 'arbitrum'
  else if chain = Base then
    Result := 'base'
  else if chain = PulseChain then
    Result := 'pulse';
end;

function coin(const chain: TChain; const address: TAddress; const callback: TProc<ICoin, IError>): IAsyncResult;
begin
  Result := coin(chain, address, procedure(obj: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const coins = getPropAsObj(obj, 'coins');
    if not Assigned(coins) then
    begin
      callback(nil, TError.Create('coins is null'));
      EXIT;
    end;
    const coin = getPropAsObj(coins, Format('%s:%s', [network(chain), address.ToChecksum]));
    if not Assigned(coin) then
    begin
      callback(nil, TError.Create('coins.%s:%s is null', [network(chain), address.ToChecksum]));
      EXIT;
    end;
    callback(TCoin.Create(coin), nil);
  end);
end;

function coin(const chain: TChain; const address: TAddress; const callback: TProc<TJsonValue, IError>): IAsyncResult;
begin
  Result := web3.http.get(
    Format('https://coins.llama.fi/prices/current/%s:%s/', [network(chain), address.ToChecksum]),
    [], callback
  );
end;

function price(const chain: TChain; const address: TAddress; const callback: TProc<Double, IError>): IAsyncResult;
begin
  Result := coin(chain, address, procedure(coin: ICoin; err: IError)
  begin
    if not Assigned(coin) then
      callback(0, err)
    else
      callback(coin.Price, err);
  end);
end;

end.
