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

unit web3.eth.rari.capital.api;

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
  IRariStats = interface
    function StablePoolAPY: Double;
    function EthPoolAPY   : Double;
    function YieldPoolAPY : Double;
    function DaiPoolAPY   : Double;
  end;

function stats(callback: TProc<IRariStats, IError>): IAsyncResult; overload;
function stats(callback: TProc<TJsonObject, IError>): IAsyncResult; overload;

implementation

uses
  // web3
  web3.json;

{--------------------------------- TRariStats ---------------------------------}

type
  TRariStats = class(TDeserialized<TJsonObject>, IRariStats)
  public
    function StablePoolAPY: Double;
    function EthPoolAPY   : Double;
    function YieldPoolAPY : Double;
    function DaiPoolAPY   : Double;
  end;

function TRariStats.StablePoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'stablePoolAPY');
end;

function TRariStats.EthPoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'ethPoolAPY');
end;

function TRariStats.YieldPoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'yieldPoolAPY');
end;

function TRariStats.DaiPoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonValue, 'daiPoolAPY');
end;

{------------------------------ global functions ------------------------------}

function stats(callback: TProc<IRariStats, IError>): IAsyncResult;
begin
  Result := stats(procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TRariStats.Create(obj), nil);
  end);
end;

function stats(callback: TProc<TJsonObject, IError>): IAsyncResult;
begin
  Result := web3.http.get('https://v2.rari.capital/api/stats', [], callback);
end;

end.
