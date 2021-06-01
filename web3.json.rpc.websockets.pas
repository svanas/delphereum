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
    FOnError: TAsyncError;
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
      callback    : TAsyncJsonObject); overload; virtual; abstract;

    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject); virtual; abstract;
    procedure Unsubscribe(const subscription: string); virtual; abstract;
    procedure Disconnect; virtual; abstract;

    function OnError(Value: TAsyncError): IPubSub;
    function OnDisconnect(Value: TProc): IPubSub;
  end;

implementation

function TJsonRpcWebSocket.OnError(Value: TAsyncError): IPubSub;
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
