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

unit web3.json.rpc.sgc.websockets;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // SgcWebSockets
  sgcWebSocket,
  sgcWebSocket_Classes,
  sgcWebSocket_Types,
  // web3
  web3,
  web3.json.rpc.websockets,
  web3.sync;

type
  TCallbacks     = TCriticalDictionary<Int64, TAsyncJsonObject>;
  TSubscriptions = TCriticalDictionary<string, TAsyncJsonObject>;

  TJsonRpcSgcWebSocket = class(TJsonRpcWebSocket)
  strict private
    FClient        : TsgcWebSocketClient;
    FCallbacks     : TCallbacks;
    FSubscriptions : TSubscriptions;
    function GetClient(const URL: string; Security: TSecurity): TsgcWebSocketClient;
    function GetCallbacks: TCallbacks;
    function GetSubscriptions: TSubscriptions;
  strict protected
    function  TryJsonRpcError(const Text: string): Boolean;
    procedure DoMessage(Conn: TsgcWsConnection; const Text: string);
    procedure DoError(Conn: TsgcWsConnection; const Error: string);
    procedure DoException(Conn: TsgcWsConnection; E: Exception);
    procedure DoDisconnect(Conn: TsgcWsConnection; Code: Integer);
    property Client[const URL: string; Security: TSecurity]: TsgcWebSocketClient read GetClient;
    property Callbacks: TCallbacks read GetCallbacks;
    property Subscriptions: TSubscriptions read GetSubscriptions;
  public
    destructor Destroy; override;
    function Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): TJsonObject; overload; override;
    procedure Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const;
      callback    : TAsyncJsonObject); overload; override;
    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject); override;
    procedure Unsubscribe(const subscription: string); override;
    procedure Disconnect; override;
  end;

implementation

uses
  // web3
  web3.json,
  web3.json.rpc;

{ TJsonRpcSgcWebSocket }

function TJsonRpcSgcWebSocket.GetClient(const URL: string; Security: TSecurity): TsgcWebSocketClient;
begin
  if not Assigned(FClient) then
  begin
    FClient := TsgcWebSocketClient.Create(nil);
    FClient.NotifyEvents := neNoSync;

    FClient.OnMessage    := DoMessage;
    FClient.OnError      := DoError;
    FClient.OnException  := DoException;
    FClient.OnDisconnect := DoDisconnect;

    FClient.HeartBeat.Enabled  := True;
    FClient.HeartBeat.Interval := 30; // seconds
    FClient.HeartBeat.Timeout  := 0;
  end;

  if not URL.Contains(FClient.Host) then
  begin
    if FClient.Active then FClient.Disconnect;

    case Security of
      TLS_10: FClient.TLSOptions.Version := tls1_0;
      TLS_11: FClient.TLSOptions.Version := tls1_1;
      TLS_12: FClient.TLSOptions.Version := tls1_2;
      TLS_13: FClient.TLSOptions.Version := tls1_3;
    end;

    FClient.URL := URL;
  end;

  if not FClient.Active then repeat until FClient.Connect;

  Result := FClient;
end;

function TJsonRpcSgcWebSocket.GetCallbacks: TCallbacks;
begin
  if not Assigned(FCallbacks) then FCallbacks := TCallbacks.Create;
  Result := FCallbacks;
end;

function TJsonRpcSgcWebSocket.GetSubscriptions: TSubscriptions;
begin
  if not Assigned(FSubscriptions) then FSubscriptions := TSubscriptions.Create;
  Result := FSubscriptions;
end;

destructor TJsonRpcSgcWebSocket.Destroy;
begin
  if Assigned(FSubscriptions) then
  try
    FSubscriptions.Clear;
  finally
    FSubscriptions.Free;
  end;

  if Assigned(FCallbacks) then
  try
    FCallbacks.Clear;
  finally
    FCallbacks.Free;
  end;

  if Assigned(FClient) then
  try
    if FClient.Active then FClient.Disconnect;
  finally
    FClient.Free;
  end;

  inherited Destroy;
end;

function TJsonRpcSgcWebSocket.TryJsonRpcError(const Text: string): Boolean;
begin
  const response = web3.json.unmarshal(Text);

  Result := Assigned(response);
  if not Result then
    EXIT;

  var callback: TAsyncJsonObject;
  try
    // did we receive an error?
    const error = web3.json.getPropAsObj(response, 'error');
    Result := Assigned(error);
    if not Result then
      EXIT;

    Callbacks.Enter;
    try
      // do we have an attr named "id"? if yes, then this is a JSON-RPC error.
      Result := Callbacks.TryGetValue(web3.json.getPropAsInt(response, 'id'), callback);
      if Result then
      begin
        Callbacks.Remove(web3.json.getPropAsInt(response, 'id'));
        callback(nil, TJsonRpcError.Create(
          web3.json.getPropAsInt(error, 'code'),
          web3.json.getPropAsStr(error, 'message')
        ));
        EXIT;
      end;
    finally
      Callbacks.Leave;
    end;

    // otherwise, do we have an attr named "params"? if yes, then this is a PubSub error.
    const params = web3.json.getPropAsObj(response, 'params');
    if Assigned(params) then
    begin
      Subscriptions.Enter;
      try
        Result := Subscriptions.TryGetValue(web3.json.getPropAsStr(params, 'subscription'), callback);
      finally
        Subscriptions.Leave;
      end;
      if Result then
        callback(nil, TJsonRpcError.Create(
          web3.json.getPropAsInt(error, 'code'),
          web3.json.getPropAsStr(error, 'message')
        ));
    end;
  finally
    response.Free;
  end;
end;

procedure TJsonRpcSgcWebSocket.DoMessage(Conn: TsgcWsConnection; const Text: string);
begin
  if TryJsonRpcError(Text) then
    EXIT;

  const response = web3.json.unmarshal(Text);

  if not Assigned(response) then
  begin
    if Assigned(FOnError) then FOnError(TError.Create(Text));
    EXIT;
  end;

  var callback: TAsyncJsonObject;
  try
    Callbacks.Enter;
    try
      // do we have an attr named "id"? if yes, then this is a JSON-RPC response.
      if Callbacks.TryGetValue(web3.json.getPropAsInt(response, 'id'), callback) then
      begin
        Callbacks.Remove(web3.json.getPropAsInt(response, 'id'));
        callback(response.Clone as TJsonObject, nil);
        EXIT;
      end;
    finally
      Callbacks.Leave;
    end;
    // otherwise, do we have an attr named "params"? if yes, then this is a PubSub notification.
    const params = web3.json.getPropAsObj(response, 'params');
    if Assigned(params) then
      if Subscriptions.TryGetValue(web3.json.getPropAsStr(params, 'subscription'), callback) then
        callback(response.Clone as TJsonObject, nil);
  finally
    response.Free;
  end;
end;

procedure TJsonRpcSgcWebSocket.DoError(Conn: TsgcWsConnection; const Error: string);
begin
  if TryJsonRpcError(Error) then
    EXIT;
  if Assigned(FOnError) then FOnError(TError.Create(Error));
end;

procedure TJsonRpcSgcWebSocket.DoException(Conn: TsgcWsConnection; E: Exception);
begin
  if TryJsonRpcError(E.Message) then
    EXIT;
  if Assigned(FOnError) then FOnError(TError.Create(E.Message));
end;

procedure TJsonRpcSgcWebSocket.DoDisconnect(Conn: TsgcWsConnection; Code: Integer);
begin
  if Assigned(FOnDisconnect) then FOnDisconnect;
end;

function TJsonRpcSgcWebSocket.Call(
  const URL   : string;
  security    : TSecurity;
  const method: string;
  args        : array of const): TJsonObject;
begin
  Result := nil;
  const resp = web3.json.unmarshal(Client[URL, security].WriteAndWaitData(CreatePayload(method, args)));
  if Assigned(resp) then
  try
    // did we receive an error? then translate that into an exception
    const error = web3.json.getPropAsObj(resp, 'error');
    if Assigned(error) then
      raise EJsonRpc.Create(
        web3.json.getPropAsInt(error, 'code'),
        web3.json.getPropAsStr(error, 'message')
      );
    Result := resp.Clone as TJsonObject;
  finally
    resp.Free;
  end;
end;

procedure TJsonRpcSgcWebSocket.Call(
  const URL   : string;
  security    : TSecurity;
  const method: string;
  args        : array of const;
  callback    : TAsyncJsonObject);
begin
  const payload = (function(args: array of const): string
  begin
    Self.ID.Enter;
    try
      const ID = Self.ID.Inc;
      Callbacks.Enter;
      try
        Callbacks.Add(ID, callback);
      finally
        Callbacks.Leave;
      end;
      Result := CreatePayload(ID, method, args);
    finally
      Self.ID.Leave;
    end;
  end)(args);
  Client[URL, security].WriteData(payload);
end;

procedure TJsonRpcSgcWebSocket.Subscribe(const subscription: string; callback: TAsyncJsonObject);
begin
  Subscriptions.Enter;
  try
    Subscriptions.AddOrSetValue(subscription, callback);
  finally
    Subscriptions.Leave;
  end;
end;

procedure TJsonRpcSgcWebSocket.Unsubscribe(const subscription: string);
begin
  Subscriptions.Enter;
  try
    Subscriptions.Remove(subscription);
  finally
    Subscriptions.Leave;
  end;
end;

procedure TJsonRpcSgcWebSocket.Disconnect;
begin
  if Assigned(FClient) and FClient.Active then FClient.Disconnect;
end;

end.
