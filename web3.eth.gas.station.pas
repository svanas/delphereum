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
  System.Types,
  // web3
  web3,
  web3.http;

type
  IGasPrice = interface
    function Fastest: TWei;
    function Fast   : TWei; // expected to be mined in < 2 minutes
    function Average: TWei; // expected to be mined in < 5 minutes
    function SafeLow: TWei; // expected to be mined in < 30 minutes
  end;

  TAsyncGasPrice = reference to procedure(price: IGasPrice; err: IError);

function getGasPrice(
  const apiKey: string;
  callback    : TAsyncGasPrice): IAsyncResult; overload;
function getGasPrice(
  const apiKey: string;
  callback    : TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  System.NetEncoding,
  // web3
  web3.eth.utils,
  web3.json;

type
  TGasPrice = class(TInterfacedObject, IGasPrice)
  private
    FJsonObject: TJsonObject;
  public
    function Fastest: TWei;
    function Fast   : TWei;
    function Average: TWei;
    function SafeLow: TWei;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TGasPrice.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TGasPrice.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TGasPrice.Fastest: TWei;
begin
  Result := toWei(FloatToEth(getPropAsDouble(FJsonObject, 'fastest') / 10), gwei);
end;

function TGasPrice.Fast: TWei;
begin
  Result := toWei(FloatToEth(getPropAsDouble(FJsonObject, 'fast') / 10), gwei);
end;

function TGasPrice.Average: TWei;
begin
  Result := toWei(FloatToEth(getPropAsDouble(FJsonObject, 'average') / 10), gwei);
end;

function TGasPrice.SafeLow: TWei;
begin
  Result := toWei(FloatToEth(getPropAsDouble(FJsonObject, 'safeLow') / 10), gwei);
end;

function getGasPrice(const apiKey: string; callback: TAsyncGasPrice): IAsyncResult;
begin
  Result := getGasPrice(apiKey, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TGasPrice.Create(obj.Clone as TJsonObject), nil);
  end);
end;

function getGasPrice(const apiKey: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get(
    'https://ethgasstation.info/api/ethgasAPI.json?api-key=' + TNetEncoding.URL.Encode(apiKey),
    callback
  );
end;

end.
