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
  System.SysUtils,
  // web3
  web3,
  web3.json.rpc;

type
  TJsonRpcWebSockets = class abstract(TCustomJsonRpc, IPubSub)
  strict private
    FOnError: TAsyncError;
    FOnDisconnect: TProc;
    procedure SetOnError(Value: TAsyncError);
    procedure SetOnDisconnect(Value: TProc);
  strict protected
    property OnError: TAsyncError read FOnError write SetOnError;
    property OnDisconnect: TProc read FOnDisconnect write SetOnDisconnect;
  public
    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject); virtual; abstract;
    procedure Unsubscribe(const subscription: string); virtual; abstract;
    procedure Disconnect; virtual; abstract;
  end;

implementation

procedure TJsonRpcWebSockets.SetOnError(Value: TAsyncError);
begin
  FOnError := Value;
end;

procedure TJsonRpcWebSockets.SetOnDisconnect(Value: TProc);
begin
  FOnDisconnect := Value;
end;

end.
