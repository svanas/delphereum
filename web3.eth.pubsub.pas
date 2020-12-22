{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{                  https://geth.ethereum.org/docs/rpc/pubsub                   }
{                                                                              }
{******************************************************************************}

unit web3.eth.pubsub;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  TSubscription = (
    logs,
    newHeads,
    newPendingTransactions,
    syncing
  );

procedure subscribe(
  client      : TWeb3;
  subscription: TSubscription;
  callback    : TAsyncString;     // one-time callback (subscribed, or a JSON-RPC error)
  notification: TAsyncJsonObject; // continuous notifications (or a JSON-RPC error)
  onError     : TOnError;         // non-JSON-RPC-error handler (probably a socket error)
  onDisconnect: TProc);           // connection closed

procedure unsubscribe(
  client            : TWeb3;
  const subscription: string;         // as returned by the eth_subscribe callback
  callback          : TAsyncBoolean); // true if successful, otherwise false

function blockNumber(notification: TJsonObject): BigInteger;

implementation

uses
  // Delphi
  System.TypInfo,
  // web3
  web3.json;

{---------------------------- TSubscriptionHelper -----------------------------}

type
  TSubscriptionHelper = record helper for TSubscription
  public
    function ToString: string;
  end;

function TSubscriptionHelper.ToString: string;
begin
  Result := GetEnumName(TypeInfo(TSubscription), Ord(Self));
end;

{---------------------------------- globals -----------------------------------}

procedure subscribe(
  client      : TWeb3;
  subscription: TSubscription;
  callback    : TAsyncString;
  notification: TAsyncJsonObject;
  onError     : TOnError;
  onDisconnect: TProc);
var
  pubSub: IPubSub;
  result: string;
begin
  pubSub := client.PubSub;
  if not Assigned(pubSub) then
  begin
    callback('', TError.Create('not a WebSocket'));
    EXIT;
  end;

  pubSub.OnError      := onError;
  pubSub.OnDisconnect := onDisconnect;

  client.JsonRpc.Send(client.URL, client.Security, 'eth_subscribe', [subscription.ToString], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;

    result := web3.json.getPropAsStr(resp, 'result');
    callback(result, nil);

    pubSub.Subscribe(result, notification);
  end);
end;

procedure unsubscribe(
  client            : TWeb3;
  const subscription: string;
  callback          : TAsyncBoolean);
var
  result: Boolean;
begin
  client.JsonRpc.Send(client.URL, client.Security, 'eth_unsubscribe', [subscription], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(False, err);
      EXIT;
    end;

    result := web3.json.getPropAsStr(resp, 'result').Equals('true');
    callback(result, nil);

    if result then
      client.PubSub.Unsubscribe(subscription);
  end);
end;

function blockNumber(notification: TJsonObject): BigInteger;
var
  params : TJsonObject;
  _result: TJsonObject;
begin
  Result := 0;
  params := web3.json.getPropAsObj(notification, 'params');
  if Assigned(params) then
  begin
    _result := web3.json.getPropAsObj(params, 'result');
    if Assigned(_result) then
      Result := web3.json.getPropAsStr(_result, 'number');
  end;
end;

end.
