{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{                    https://docs.blocknative.com/websocket                    }
{                                                                              }
{******************************************************************************}

unit web3.eth.blocknative.mempool.sgc;

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
  // web3;
  web3,
  web3.eth.blocknative.mempool,
  web3.json;

type
  TSgcMempool = class(TCustomMempool, IMempool)
  strict private
    FClient: TsgcWebSocketClient;
    function GetClient: TsgcWebSocketClient;
  strict protected
    function  TryBlocknativeError(const Text: string): Boolean;
    procedure DoMessage(Conn: TsgcWsConnection; const Text: string);
    procedure DoError(Conn: TsgcWsConnection; const Error: string);
    procedure DoException(Conn: TsgcWsConnection; E: Exception);
    procedure DoDisconnect(Conn: TsgcWsConnection; Code: Integer);
    property  Client: TsgcWebSocketClient read GetClient;
  public
    constructor Create(
      const chain : TChain;
      const apiKey: string;
      onEvent     : TAsyncJsonObject;
      onError     : TAsyncError;
      onDisconnect: TProc);
    destructor Destroy; override;
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;
      const address: TAddress;
      onEvent      : TAsyncJsonObject;
      onError      : TAsyncError;
      onDisconnect : TProc): IMempool; overload; override;
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;
      const address: TAddress;
      const filters: IFilters;
      const abi    : TJsonArray;
      onEvent      : TAsyncJsonObject;
      onError      : TAsyncError;
      onDisconnect : TProc): IMempool; overload; override;
    procedure Unsubscribe(const address: TAddress);
    procedure Initialize;
    procedure Disconnect;
    function  Connected: Boolean;
  end;

implementation

constructor TSgcMempool.Create(
  const chain : TChain;
  const apiKey: string;
  onEvent     : TAsyncJsonObject;
  onError     : TAsyncError;
  onDisconnect: TProc);
begin
  inherited Create;
  FChain   := chain;
  FApiKey  := apiKey;
  FOnEvent := onEvent;
  FOnError := onError;
  FOnDisconnect := onDisconnect;
end;

function TSgcMempool.GetClient: TsgcWebSocketClient;
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

    FClient.URL := BLOCKNATIVE_ENDPOINT;
  end;

  if not FClient.Active then repeat until FClient.Connect;

  Result := FClient;
end;

destructor TSgcMempool.Destroy;
begin
  if Assigned(FClient) then
  try
    if FClient.Active then FClient.Disconnect;
  finally
    FClient.Free;
  end;
  inherited Destroy;
end;

function TSgcMempool.TryBlocknativeError(const Text: string): Boolean;
var
  response: TJsonValue;
begin
  response := unmarshal(Text);
  Result := Assigned(response);
  if Result then
  try
    // did we receive an error?
    Result := SameText(getPropAsStr(response, 'status'), 'error');
    if not Result then
      EXIT;
    if Assigned(FOnEvent) then
      FOnEvent(nil, TError.Create(getPropAsStr(response, 'reason')));
  finally
    response.Free;
  end;
end;

procedure TSgcMempool.DoMessage(Conn: TsgcWsConnection; const Text: string);
var
  response: TJsonValue;
  event   : TJsonObject;
begin
  if TryBlocknativeError(Text) then
    EXIT;

  response := unmarshal(Text);

  if not Assigned(response) then
  begin
    if Assigned(FOnError) then FOnError(TError.Create(Text));
    EXIT;
  end;

  try
    event := getPropAsObj(response, 'event');
    if not Assigned(event) then
      EXIT;
    if Assigned(FOnEvent) then FOnEvent(event, nil);
  finally
    response.Free;
  end;
end;

procedure TSgcMempool.DoError(Conn: TsgcWsConnection; const Error: string);
begin
  if TryBlocknativeError(Error) then
    EXIT;
  if Assigned(FOnError) then FOnError(TError.Create(Error));
end;

procedure TSgcMempool.DoException(Conn: TsgcWsConnection; E: Exception);
begin
  if TryBlocknativeError(E.Message) then
    EXIT;
  if Assigned(FOnError) then FOnError(TError.Create(E.Message));
end;

procedure TSgcMempool.DoDisconnect(Conn: TsgcWsConnection; Code: Integer);
begin
  if Assigned(FOnDisconnect) then FOnDisconnect;
end;

class function TSgcMempool.Subscribe(
  const chain  : TChain;
  const apiKey : string;
  const address: TAddress;
  onEvent      : TAsyncJsonObject;
  onError      : TAsyncError;
  onDisconnect : TProc): IMempool;
var
  &output: TSgcMempool;
  payload: TJsonObject;
begin
  &output := TSgcMempool.Create(
    chain,
    apiKey,
    onEvent,
    onError,
    onDisconnect
  );

  &output.Initialize;

  payload := unmarshal(&output.CreatePayload('accountAddress', 'watch')) as TJsonObject;
  if Assigned(payload) then
  try
    payload.AddPair('account', unmarshal(Format('{"address":"%s"}', [address])));
    &output.Client.WriteData(marshal(payload));
  finally
    payload.Free;
  end;

  Result := &output;
end;

class function TSgcMempool.Subscribe(
  const chain  : TChain;
  const apiKey : string;
  const address: TAddress;
  const filters: IFilters;
  const abi    : TJsonArray;
  onEvent      : TAsyncJsonObject;
  onError      : TAsyncError;
  onDisconnect : TProc): IMempool;
var
  &output: TSgcMempool;
  payload: TJsonObject;
  config : TJsonObject;
begin
  &output := TSgcMempool.Create(
    chain,
    apiKey,
    onEvent,
    onError,
    onDisconnect
  );

  &output.Initialize;

  payload := unmarshal(&output.CreatePayload('configs', 'put')) as TJsonObject;
  if Assigned(payload) then
  try
    config := unmarshal(Format('{"scope":"%s","watchAddress":true}', [address])) as TJsonObject;
    if Assigned(config) then
    begin
      if Assigned(filters) then
        config.AddPair('filters', filters.AsArray);
      if Assigned(abi) then
        config.AddPair('abi', abi);
      payload.AddPair('config', config);
    end;
    &output.Client.WriteData(marshal(payload));
  finally
    payload.Free;
  end;

  Result := &output;
end;

procedure TSgcMempool.Unsubscribe(const address: TAddress);
var
  payload: TJsonObject;
begin
  payload := unmarshal(CreatePayload('accountAddress', 'unwatch')) as TJsonObject;
  if Assigned(payload) then
  try
    payload.AddPair('account', unmarshal(Format('{"address":"%s"}', [address])));
    Client.WriteData(marshal(payload));
  finally
    payload.Free;
  end;
end;

procedure TSgcMempool.Initialize;
begin
  Client.WriteData(CreatePayload('initialize', 'checkDappId'));
end;

procedure TSgcMempool.Disconnect;
begin
  if Self.Connected then FClient.Disconnect;
end;

function TSgcMempool.Connected: Boolean;
begin
  Result := Assigned(FClient) and FClient.Active;
end;

end.
