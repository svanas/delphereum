{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
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
      onEvent     : TProc<TJsonObject, IError>;
      onError     : TProc<IError>;
      onDisconnect: TProc);
    destructor Destroy; override;
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;
      const address: TAddress;
      onEvent      : TProc<TJsonObject, IError>;
      onError      : TProc<IError>;
      onDisconnect : TProc): IMempool; overload; override;
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;
      const address: TAddress;
      const filters: IFilters;
      const abi    : TJsonArray;
      onEvent      : TProc<TJsonObject, IError>;
      onError      : TProc<IError>;
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
  onEvent     : TProc<TJsonObject, IError>;
  onError     : TProc<IError>;
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
begin
  const response = unmarshal(Text);
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
begin
  if TryBlocknativeError(Text) then
    EXIT;

  const response = unmarshal(Text);

  if not Assigned(response) then
  begin
    if Assigned(FOnError) then FOnError(TError.Create(Text));
    EXIT;
  end;

  try
    const event = getPropAsObj(response, 'event');
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
  onEvent      : TProc<TJsonObject, IError>;
  onError      : TProc<IError>;
  onDisconnect : TProc): IMempool;
begin
  const &output = TSgcMempool.Create(
    chain,
    apiKey,
    onEvent,
    onError,
    onDisconnect
  );

  &output.Initialize;

  const payload = unmarshal(&output.CreatePayload('accountAddress', 'watch')) as TJsonObject;
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
  onEvent      : TProc<TJsonObject, IError>;
  onError      : TProc<IError>;
  onDisconnect : TProc): IMempool;
begin
  const &output = TSgcMempool.Create(
    chain,
    apiKey,
    onEvent,
    onError,
    onDisconnect
  );

  &output.Initialize;

  const payload = unmarshal(&output.CreatePayload('configs', 'put')) as TJsonObject;
  if Assigned(payload) then
  try
    const config = unmarshal(Format('{"scope":"%s","watchAddress":true}', [address])) as TJsonObject;
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
begin
  const payload = unmarshal(CreatePayload('accountAddress', 'unwatch')) as TJsonObject;
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
