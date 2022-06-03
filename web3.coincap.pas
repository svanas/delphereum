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
  System.Types,
  // web3
  web3,
  web3.http;

type
  ITicker = interface
    function Symbol: string; // most common symbol used to identify this asset on an exchange
    function Price : Double; // volume-weighted price based on real-time market data, translated to USD
  end;

  TAsyncTicker = reference to procedure(const ticker: ITicker; err: IError);

function ticker(const asset: string; callback: TAsyncTicker): IAsyncResult; overload;
function ticker(const asset: string; callback: TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  System.NetEncoding,
  // web3
  web3.json;

type
  TTicker = class(TDeserialized<TJsonObject>, ITicker)
  public
    function Symbol: string;
    function Price : Double;
  end;

function TTicker.Symbol: string;
begin
  Result := getPropAsStr(FJsonValue, 'symbol');
end;

function TTicker.Price: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'priceUsd');
end;

function ticker(const asset: string; callback: TAsyncTicker): IAsyncResult;
begin
  Result := ticker(asset, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const data = getPropAsObj(obj, 'data');
    if not Assigned(data) then
    begin
      callback(nil, TError.Create('%s.data is null', [asset]));
      EXIT;
    end;
    callback(TTicker.Create(data), nil);
  end);
end;

function ticker(const asset: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get(
    'https://api.coincap.io/v2/assets/' + TNetEncoding.URL.Encode(asset),
    [], callback
  );
end;

end.
