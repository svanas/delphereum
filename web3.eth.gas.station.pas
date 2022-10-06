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

unit web3.eth.gas.station;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3,
  web3.http;

type
  IGasPrice = interface
    function Fastest: IResult<TWei>;
    function Fast   : IResult<TWei>; // expected to be mined in < 2 minutes
    function Average: IResult<TWei>; // expected to be mined in < 5 minutes
    function SafeLow: IResult<TWei>; // expected to be mined in < 30 minutes
  end;

function getGasPrice(
  const apiKey: string;
  callback    : TProc<IGasPrice, IError>): IAsyncResult; overload;
function getGasPrice(
  const apiKey: string;
  callback    : TProc<TJsonObject, IError>): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.NetEncoding,
  // web3
  web3.eth.utils,
  web3.json;

type
  TGasPrice = class(TDeserialized<TJsonObject>, IGasPrice)
  public
    function Fastest: IResult<TWei>;
    function Fast   : IResult<TWei>;
    function Average: IResult<TWei>;
    function SafeLow: IResult<TWei>;
  end;

function TGasPrice.Fastest: IResult<TWei>;
begin
  Result := toWei(FloatToDot(getPropAsDouble(FJsonValue, 'fastest') / 10), gwei);
end;

function TGasPrice.Fast: IResult<TWei>;
begin
  Result := toWei(FloatToDot(getPropAsDouble(FJsonValue, 'fast') / 10), gwei);
end;

function TGasPrice.Average: IResult<TWei>;
begin
  Result := toWei(FloatToDot(getPropAsDouble(FJsonValue, 'average') / 10), gwei);
end;

function TGasPrice.SafeLow: IResult<TWei>;
begin
  Result := toWei(FloatToDot(getPropAsDouble(FJsonValue, 'safeLow') / 10), gwei);
end;

function getGasPrice(const apiKey: string; callback: TProc<IGasPrice, IError>): IAsyncResult;
begin
  Result := getGasPrice(apiKey, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TGasPrice.Create(obj), nil);
  end);
end;

function getGasPrice(const apiKey: string; callback: TProc<TJsonObject, IError>): IAsyncResult;
begin
  Result := web3.http.get(
    'https://ethgasstation.info/api/ethgasAPI.json?api-key=' + TNetEncoding.URL.Encode(apiKey),
    [], callback
  );
end;

end.
