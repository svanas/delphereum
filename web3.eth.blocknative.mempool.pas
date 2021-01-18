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
  BLOCKNATIVE_ENDPOINT = 'wss://api.blocknative.com/v0';

type
  TEventCode = (
    txUnknown,
    txSent,      // Transaction has been sent to the network
    txPool,      // Transaction was detected in the "pending" area of the mempool and is eligible for inclusion in a block
    txStuck,     // Transaction was detected in the "queued" area of the mempool and is not eligible for inclusion in a block
    txConfirmed, // Transaction has been mined
    txFailed,    // Transaction has failed
    txSpeedUp,   // A new transaction has been submitted with the same nonce and a higher gas price, replacing the original transaction
    txCancel,    // A new transaction has been submitted with the same nonce, a higher gas price, a value of zero and sent to an external address (not a contract)
    txDropped    // Transaction was dropped from the mempool without being added to a block
  );

type
  IMempool = interface
    procedure Unsubscribe(const address: TAddress);
    procedure Disconnect;
  end;

type
  TCustomMempool = class abstract(TInterfacedObject)
  protected
    FChain  : TChain;
    FApiKey : string;
    FOnEvent: TAsyncJsonObject;
    FOnError: TAsyncError;
    FOnDisconnect: TProc;
    function GetPayload(
      const categoryCode: string;
      const eventCode   : string): string;
  public
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;           // your blocknative API key
      const address: TAddress;         // address to watch
      onEvent      : TAsyncJsonObject; // continuous events (or a blocknative error)
      onError      : TAsyncError;      // non-blocknative-error handler (probably a socket error)
      onDisconnect : TProc             // connection closed
    ): IMempool; overload; virtual; abstract;
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;           // your blocknative API key
      const address: TAddress;         // address to watch
      const method : string;           // method name filter, for example: "transfer" (no quotes)
      onEvent      : TAsyncJsonObject; // continuous events (or a blocknative error)
      onError      : TAsyncError;      // non-blocknative-error handler (probably a socket error)
      onDisconnect : TProc             // connection closed
    ): IMempool; overload; virtual; abstract;
    class function Subscribe(
      const chain  : TChain;
      const apiKey : string;           // your blocknative API key
      const address: TAddress;         // address to watch
      const filters: TJsonArray;       // an array of valid filters. please see: https://github.com/deitch/searchjs
      const abi    : TJsonArray;       // a valid ABI that will be used to decode input data for transactions
      onEvent      : TAsyncJsonObject; // continuous events (or a blocknative error)
      onError      : TAsyncError;      // non-blocknative-error handler (probably a socket error)
      onDisconnect : TProc             // connection closed
    ): IMempool; overload; virtual; abstract;
  end;

function getEventCode  (const event: TJsonObject): TEventCode;
function getTransaction(const event: TJsonObject): TJsonObject;

implementation

uses
  // Delphi
  System.DateUtils,
  // web3
  web3.json;

function getEventCode(const event: TJsonObject): TEventCode;
const
  EVENT_CODE: array[TEventCode] of string = (
    '',            // txUnknown,
    'txSent',      // Transaction has been sent to the network
    'txPool',      // Transaction was detected in the "pending" area of the mempool and is eligible for inclusion in a block
    'txStuck',     // Transaction was detected in the "queued" area of the mempool and is not eligible for inclusion in a block
    'txConfirmed', // Transaction has been mined
    'txFailed',    // Transaction has failed
    'txSpeedUp',   // A new transaction has been submitted with the same nonce and a higher gas price, replacing the original transaction
    'txCancel',    // A new transaction has been submitted with the same nonce, a higher gas price, a value of zero and sent to an external address (not a contract)
    'txDropped'    // Transaction was dropped from the mempool without being added to a block
  );
var
  eventCode: string;
begin
  eventCode := getPropAsStr(event, 'eventCode');
  if eventCode <> '' then
    for Result := Low(TEventCode) to High(TEventCode) do
      if EVENT_CODE[Result] = eventCode then
        EXIT;
  Result := txUnknown;
end;

function getTransaction(const event: TJsonObject): TJsonObject;
begin
  Result := getPropAsObj(event, 'transaction');
end;

{------------------------------- TCustomMempool -------------------------------}

function TCustomMempool.GetPayload(
  const categoryCode: string;
  const eventCode   : string): string;
const
  NETWORK: array[TChain] of string = (
    'main',    // Mainnet,
    'ropsten', // Ropsten
    'rinkeby', // Rinkeby
    'goerli',  // Goerli
    '',        // RSK_main_net
    '',        // RSK_test_net
    'kovan',   // Kovan
    'xdai'     // xDai
  );
begin
  Result := Format('{' +
    '"categoryCode": "%s"' +
    ',"eventCode"  : "%s"' +
    ',"timeStamp"  : "%s"' +
    ',"dappId"     : "%s"' +
    ',"version"    : "0"' +
    ',"blockchain" : {"system": "ethereum", "network": "%s"}'+
  '}', [categoryCode, eventCode, DateToISO8601(System.SysUtils.Now, False), FApiKey, NETWORK[FChain]]);
end;

end.
