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

unit web3.json.rpc.sgc.websockets;

{$I web3.inc}

interface

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  // SgcWebSockets
  sgcWebSocket,
  sgcWebSocket_Classes,
  sgcWebSocket_Types,
  // web3
  web3,
  web3.json.rpc.websockets;

type
  TCallbacks     = TDictionary<Int64, TAsyncJsonObject>;
  TSubscriptions = TDictionary<string, TAsyncJsonObject>;

  TJsonRpcSgcWebSockets = class(TJsonRpcWebSockets)
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
    function Send(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): TJsonObject; overload; override;
    procedure Send(
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

{ TJsonRpcSgcWebSockets }

function TJsonRpcSgcWebSockets.GetClient(const URL: string; Security: TSecurity): TsgcWebSocketClient;
begin
  if not Assigned(FClient) then
  begin
    FClient := TsgcWebSocketClient.Create(nil);

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

  if not FClient.Active then FClient.Connect;

  Result := FClient;
end;

function TJsonRpcSgcWebSockets.GetCallbacks: TCallbacks;
begin
  if not Assigned(FCallbacks) then FCallbacks := TCallbacks.Create;
  Result := FCallbacks;
end;

function TJsonRpcSgcWebSockets.GetSubscriptions: TSubscriptions;
begin
  if not Assigned(FSubscriptions) then FSubscriptions := TSubscriptions.Create;
  Result := FSubscriptions;
end;

destructor TJsonRpcSgcWebSockets.Destroy;
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

function TJsonRpcSgcWebSockets.TryJsonRpcError(const Text: string): Boolean;
var
  response: TJsonValue;
  error   : TJsonObject;
  callback: TAsyncJsonObject;
  params  : TJsonObject;
begin
  response := web3.json.unmarshal(Text);

  Result := Assigned(response);
  if not Result then
    EXIT;

  try
    // did we receive an error?
    error := web3.json.getPropAsObj(response, 'error');
    Result := Assigned(error);
    if not Result then
      EXIT;

    Result := Callbacks.TryGetValue(web3.json.getPropAsInt(response, 'id'), callback);
    if Result then
    begin
      callback(nil, TJsonRpcError.Create(
        web3.json.getPropAsInt(error, 'code'),
        web3.json.getPropAsStr(error, 'message')
      ));
      Callbacks.Remove(web3.json.getPropAsInt(response, 'id'));
      EXIT;
    end;

    params := web3.json.getPropAsObj(response, 'params');
    if Assigned(params) then
    begin
      Result := Subscriptions.TryGetValue(web3.json.getPropAsStr(params, 'subscription'), callback);
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

procedure TJsonRpcSgcWebSockets.DoMessage(Conn: TsgcWsConnection; const Text: string);
var
  response: TJsonValue;
  callback: TAsyncJsonObject;
  params  : TJsonObject;
begin
  Self.Enter;
  try
    if TryJsonRpcError(Text) then
      EXIT;

    response := web3.json.unmarshal(Text);

    if not Assigned(response) then
    begin
      if Assigned(OnError) then OnError(TError.Create(Text));
      EXIT;
    end;

    try
      if Callbacks.TryGetValue(web3.json.getPropAsInt(response, 'id'), callback) then
      begin
        callback(response.Clone as TJsonObject, nil);
        Callbacks.Remove(web3.json.getPropAsInt(response, 'id'));
        EXIT;
      end;

      params := web3.json.getPropAsObj(response, 'params');
      if Assigned(params) then
        if Subscriptions.TryGetValue(web3.json.getPropAsStr(params, 'subscription'), callback) then
          callback(response.Clone as TJsonObject, nil);
    finally
      response.Free;
    end;
  finally
    Self.Leave;
  end;
end;

procedure TJsonRpcSgcWebSockets.DoError(Conn: TsgcWsConnection; const Error: string);
begin
  Self.Enter;
  try
    if TryJsonRpcError(Error) then
      EXIT;
    if Assigned(OnError) then OnError(TError.Create(Error));
  finally
    Self.Leave;
  end;
end;

procedure TJsonRpcSgcWebSockets.DoException(Conn: TsgcWsConnection; E: Exception);
begin
  Self.Enter;
  try
    if TryJsonRpcError(E.Message) then
      EXIT;
    if Assigned(OnError) then OnError(TError.Create(E.Message));
  finally
    Self.Leave;
  end;
end;

procedure TJsonRpcSgcWebSockets.DoDisconnect(Conn: TsgcWsConnection; Code: Integer);
begin
  Self.Enter;
  try
    if Assigned(OnDisconnect) then OnDisconnect;
  finally
    Self.Leave;
  end;
end;

function TJsonRpcSgcWebSockets.Send(
  const URL   : string;
  security    : TSecurity;
  const method: string;
  args        : array of const): TJsonObject;
var
  resp : TJsonValue;
  error: TJsonObject;
begin
  Result := nil;
  resp := web3.json.unmarshal(Client[URL, security].WriteAndWaitData(GetPayload(method, args)));
  if Assigned(resp) then
  try
    // did we receive an error? then translate that into an exception
    error := web3.json.getPropAsObj(resp, 'error');
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

procedure TJsonRpcSgcWebSockets.Send(
  const URL   : string;
  security    : TSecurity;
  const method: string;
  args        : array of const;
  callback    : TAsyncJsonObject);
var
  ID: Int64;
begin
  Self.ID.Enter;
  try
    ID := Self.ID.Inc;
    Callbacks.Add(ID, callback);
    Client[URL, security].WriteData(GetPayload(ID, method, args));
  finally
    Self.ID.Leave;
  end;
end;

procedure TJsonRpcSgcWebSockets.Subscribe(const subscription: string; callback: TAsyncJsonObject);
begin
  Self.Enter;
  try
    Subscriptions.AddOrSetValue(subscription, callback);
  finally
    Self.Leave;
  end;
end;

procedure TJsonRpcSgcWebSockets.Unsubscribe(const subscription: string);
begin
  Self.Enter;
  try
    Subscriptions.Remove(subscription);
  finally
    Self.Leave;
  end;
end;

procedure TJsonRpcSgcWebSockets.Disconnect;
begin
  if Assigned(FClient) then
    if FClient.Active then FClient.Disconnect;
end;

end.
