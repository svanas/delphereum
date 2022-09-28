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

unit web3.json.rpc.websockets;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // web3
  web3,
  web3.json.rpc;

type
  TJsonRpcWebSocket = class abstract(TCustomJsonRpc, IPubSub)
  strict protected
    FOnError: TProc<IError>;
    FOnDisconnect: TProc;
  public
    function Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): TJsonObject; overload; virtual; abstract;
    procedure Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const;
      callback    : TProc<TJsonObject, IError>); overload; virtual; abstract;

    procedure Subscribe(const subscription: string; callback: TProc<TJsonObject, IError>); virtual; abstract;
    procedure Unsubscribe(const subscription: string); virtual; abstract;
    procedure Disconnect; virtual; abstract;

    function OnError(Value: TProc<IError>): IPubSub;
    function OnDisconnect(Value: TProc): IPubSub;
  end;

implementation

function TJsonRpcWebSocket.OnError(Value: TProc<IError>): IPubSub;
begin
  Self.FOnError := Value;
  Result := Self;
end;

function TJsonRpcWebSocket.OnDisconnect(Value: TProc): IPubSub;
begin
  Self.FOnDisconnect := Value;
  Result := Self;
end;

end.
