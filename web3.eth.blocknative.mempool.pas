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

unit web3.eth.blocknative.mempool;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // web3
  web3;

const
  BLOCKNATIVE_WEBSOCKET_ENDPOINT = 'wss://api.blocknative.com/v0';

type
  TEventCode = (
    ecUnknown,
    ecInitialize,
    ecWatch,
    ecUnwatch,
    txSent,      // Transaction has been sent to the network
    txPool,      // Transaction was detected in the "pending" area of the mempool and is eligible for inclusion in a block
    txStuck,     // Transaction was detected in the "queued" area of the mempool and is not eligible for inclusion in a block
    txConfirmed, // Transaction has been mined
    txFailed,    // Transaction has failed
    txSpeedUp,   // A new transaction has been submitted with the same nonce and a higher gas price, replacing the original transaction
    txCancel,    // A new transaction has been submitted with the same nonce, a higher gas price, a value of zero and sent to an external address (not a contract)
    txDropped    // Transaction was dropped from the mempool without being added to a block
  );

  IMempool = interface
    function  Unsubscribe(const address: TAddress): IError;
    procedure Disconnect;
    function  Connected: Boolean;
  end;

  TStatus = (
    stNone,
    stCancel,    // A new transaction has been submitted with the same nonce, a higher gas price, a value of zero and sent to an external address (not a contract)
    stConfirmed, // Transaction has been mined
    stDropped,   // Transaction was dropped from the mempool without being added to a block
    stFailed,    // Transaction has failed
    stPending,   // Transaction is waiting to get mined
    stSpeedup,   // A new transaction has been submitted with the same nonce and a higher gas price, replacing the original transaction
    stStuck      // Transaction was detected in the "queued" area of the mempool and is not eligible for inclusion in a block
  );

  TDirection = (
    dNone,
    dIncoming,
    dOutgoing
  );

  IFilters = interface
    function Status(const Value: TStatus): IFilters;
    function MethodName(const Value: string): IFilters;
    function Direction(const Value: TDirection): IFilters;
    function CounterParty(const Value: TAddress): IFilters;
    function AsArray: TJsonArray;
  end;

type
  TCustomMempool = class abstract(TInterfacedObject)
  protected
    FChain  : TChain;
    FProxy  : TProxy;
    FApiKey : string;
    FOnEvent: TProc<TJsonObject, IError>;
    FOnError: TProc<IError>;
    FOnDisconnect: TProc;
    function CreatePayload(const categoryCode, eventCode: string): IResult<string>;
  public
    class function Subscribe(
      const chain       : TChain;
      const proxy       : TProxy;                     // TProxy.Disabled will probably "just work"
      const apiKey      : string;                     // your blocknative API key
      const address     : TAddress;                   // address to watch
      const onEvent     : TProc<TJsonObject, IError>; // continuous events (or a blocknative error)
      const onError     : TProc<IError>;              // non-blocknative-error handler (probably a socket error)
      const onDisconnect: TProc                       // connection closed
    ): IResult<IMempool>; overload; virtual; abstract;
    class function Subscribe(
      const chain       : TChain;
      const proxy       : TProxy;                     // TProxy.Disabled will probably "just work"
      const apiKey      : string;                     // your blocknative API key
      const address     : TAddress;                   // address to watch
      const filters     : IFilters;                   // an array of valid filters. please see: https://github.com/deitch/searchjs
      const abi         : TJsonArray;                 // a valid ABI that will be used to decode input data for transactions
      const onEvent     : TProc<TJsonObject, IError>; // continuous events (or a blocknative error)
      const onError     : TProc<IError>;              // non-blocknative-error handler (probably a socket error)
      const onDisconnect: TProc                       // connection closed
    ): IResult<IMempool>; overload; virtual; abstract;
  end;

function Filters: IFilters;
function getEventCode  (const event: TJsonObject): TEventCode;
function getTransaction(const event: TJsonObject): TJsonObject;

implementation

uses
  // Delphi
  System.DateUtils,
  // web3
  web3.eth.blocknative,
  web3.eth.types,
  web3.json;

function getEventCode(const event: TJsonObject): TEventCode;
const
  EVENT_CODE: array[TEventCode] of string = (
    '',            // Unknown
    'checkDappId', // Initialize
    'watch',       // Watch
    'unwatch',     // Unwatch
    'txSent',      // Transaction has been sent to the network
    'txPool',      // Transaction was detected in the "pending" area of the mempool and is eligible for inclusion in a block
    'txStuck',     // Transaction was detected in the "queued" area of the mempool and is not eligible for inclusion in a block
    'txConfirmed', // Transaction has been mined
    'txFailed',    // Transaction has failed
    'txSpeedUp',   // A new transaction has been submitted with the same nonce and a higher gas price, replacing the original transaction
    'txCancel',    // A new transaction has been submitted with the same nonce, a higher gas price, a value of zero and sent to an external address (not a contract)
    'txDropped'    // Transaction was dropped from the mempool without being added to a block
  );
begin
  const eventCode = getPropAsStr(event, 'eventCode');
  if eventCode <> '' then
    for Result := System.Low(TEventCode) to High(TEventCode) do
      if EVENT_CODE[Result] = eventCode then
        EXIT;
  Result := ecUnknown;
end;

function getTransaction(const event: TJsonObject): TJsonObject;
begin
  Result := getPropAsObj(event, 'transaction');
  if Assigned(Result) then
  begin
    const contractCall = getPropAsObj(event, 'contractCall');
    if Assigned(contractCall) then
      Result.AddPair('contractCall', contractCall.Clone as TJsonObject);
  end;
end;

{------------------------------- TCustomMempool -------------------------------}

function TCustomMempool.CreatePayload(const categoryCode, eventCode: string): IResult<string>;
begin
  const network = getNetwork(FChain);
  if network.IsErr then
    Result := network
  else
    Result := TResult<string>.Ok(Format('{' +
      '"categoryCode": "%s"' +
      ',"eventCode"  : "%s"' +
      ',"timeStamp"  : "%s"' +
      ',"dappId"     : "%s"' +
      ',"version"    : "0"' +
      ',"blockchain" : {"system": "ethereum", "network": "%s"}'+
    '}', [categoryCode, eventCode, DateToISO8601(System.SysUtils.Now, False), FApiKey, network.Value]));
end;

{---------------------------------- TFilters ----------------------------------}

type
  TFilters = class(TInterfacedObject, IFilters)
  private
    FStatus: TStatus;
    FMethodName: string;
    FDirection: TDirection;
    FCounterParty: TAddress;
  public
    function Status(const Value: TStatus): IFilters;
    function MethodName(const Value: string): IFilters;
    function Direction(const Value: TDirection): IFilters;
    function CounterParty(const Value: TAddress): IFilters;
    function AsArray: TJsonArray;
  end;

function Filters: IFilters;
begin
  Result := TFilters.Create;
end;

function TFilters.Status(const Value: TStatus): IFilters;
begin
  Self.FStatus := Value;
  Result := Self;
end;

function TFilters.MethodName(const Value: string): IFilters;
begin
  Self.FMethodName := Value;
  Result := Self;
end;

function TFilters.Direction(const Value: TDirection): IFilters;
begin
  Self.FDirection := Value;
  Result := Self;
end;

function TFilters.CounterParty(const Value: TAddress): IFilters;
begin
  Self.FCounterParty := Value;
  Result := Self;
end;

function TFilters.AsArray: TJsonArray;
const
  STATUS: array[TStatus] of string = (
    '',          // None,
    'cancel',    // Cancel
    'confirmed', // Confirmed
    'dropped',   // Dropped
    'failed',    // Failed
    'pending',   // Pending
    'speedup',   // Speedup
    'stuck'      // Stuck
  );
  DIRECTION: array[TDirection] of string = (
    '',         // None
    'incoming', // Incoming
    'outgoing'  // Outgoing
  );
begin
  Result := TJsonArray.Create;
  if FStatus <> stNone then
    Result.Add(unmarshal(Format('{"status":"%s"}', [STATUS[FStatus]])) as TJsonObject);
  if FMethodName <> '' then
    Result.Add(unmarshal(Format('{"contractCall.methodName":"%s"}', [FMethodName])) as TJsonObject);
  if FDirection <> dNone then
    Result.Add(unmarshal(Format('{"direction":"%s"}', [DIRECTION[FDirection]])) as TJsonObject);
  if not FCounterParty.IsZero then
    Result.Add(unmarshal(Format('{"counterparty":"%s"}', [FCounterParty])) as TJsonObject);
end;

end.
