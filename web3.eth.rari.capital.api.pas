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

  TAsyncRariStats = reference to procedure(stats: IRariStats; err: IError);

function stats(callback: TAsyncRariStats) : IAsyncResult; overload;
function stats(callback: TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  // web3
  web3.json;

{--------------------------------- TRariStats ---------------------------------}

type
  TRariStats = class(TInterfacedObject, IRariStats)
  private
    FJsonObject: TJsonObject;
  public
    function StablePoolAPY: Double;
    function EthPoolAPY   : Double;
    function YieldPoolAPY : Double;
    function DaiPoolAPY   : Double;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TRariStats.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TRariStats.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TRariStats.StablePoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonObject, 'stablePoolAPY');
end;

function TRariStats.EthPoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonObject, 'ethPoolAPY');
end;

function TRariStats.YieldPoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonObject, 'yieldPoolAPY');
end;

function TRariStats.DaiPoolAPY: Double;
begin
  Result := getPropAsDouble(FJsonObject, 'daiPoolAPY');
end;

{------------------------------ global functions ------------------------------}

function stats(callback: TAsyncRariStats) : IAsyncResult;
begin
  Result := stats(procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TRariStats.Create(obj.Clone as TJsonObject), nil);
  end);
end;

function stats(callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get('https://v2.rari.capital/api/stats', callback);
end;

end.
