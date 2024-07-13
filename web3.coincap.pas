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

unit web3.coincap;

interface

uses
  // Delphi
  System.SysUtils,
  System.Types,
  // web3
  web3,
  web3.json;

type
  IAsset = interface
    function Id    : string; // unique identifier for asset
    function Symbol: string; // most common symbol used to identify this asset on an exchange
    function Price : Double; // volume-weighted price based on real-time market data, translated to USD
  end;

function assets(const callback: TProc<IDeserializedArray<IAsset>, IError>): IAsyncResult;
function asset(const symbol: string; const callback: TProc<IAsset, IError>): IAsyncResult;
function price(const symbol: string; const callback: TProc<Double, IError>): IAsyncResult;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.NetEncoding,
  // web3
  web3.http;

type
  TAsset = class(TDeserialized, IAsset)
  public
    function Id    : string;
    function Symbol: string;
    function Price : Double;
  end;

function TAsset.Id: string;
begin
  Result := getPropAsStr(FJsonValue, 'id');
end;

function TAsset.Symbol: string;
begin
  Result := getPropAsStr(FJsonValue, 'symbol');
end;

function TAsset.Price: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'priceUsd');
end;

type
  TAssets = class(TDeserializedArray<IAsset>)
  public
    function Item(const Index: Integer): IAsset; override;
  end;

function TAssets.Item(const Index: Integer): IAsset;
begin
{$IF CompilerVersion < 40.0}
  Result := TAsset.Create(TJsonArray(FJsonValue).Items[Index]);
{$IFEND}
{$IF CompilerVersion >= 40.0}
  Result := TAsset.Create(TJsonArray(FJsonValue)[Index]);
{$IFEND}
end;

function assets(const callback: TProc<IDeserializedArray<IAsset>, IError>): IAsyncResult;
begin
  Result := web3.http.get('https://api.coincap.io/v2/assets', [],
    procedure(obj: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      const data = getPropAsArr(obj, 'data');
      if not Assigned(data) then
      begin
        callback(nil, TError.Create('data is null'));
        EXIT;
      end;
      callback(TAssets.Create(data), nil);
    end
  );
end;

function asset(const symbol: string; const callback: TProc<IAsset, IError>): IAsyncResult;
begin
  Result := assets(procedure(assets: IDeserializedArray<IAsset>; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    for var I := 0 to Pred(assets.Count) do
    begin
      const asset = assets.Item(I);
      if SameText(asset.Symbol, symbol) then
      begin
        callback(asset, nil);
        EXIT;
      end;
    end;
    callback(nil, TError.Create('%s does not exist', [symbol]));
  end);
end;

function price(const symbol: string; const callback: TProc<Double, IError>): IAsyncResult;
begin
  Result := asset(symbol, procedure(asset: IAsset; err: IError)
  begin
    if not Assigned(asset) then
      callback(0, err)
    else
      callback(asset.Price, err);
  end);
end;

end.
