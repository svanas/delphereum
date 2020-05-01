{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.logs;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.Threading,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  TLog = record
  strict private
    FBlockNumber: BigInteger;
    FTopics     : TTopics;
    FData       : TTuple;
    function  GetTopic(idx: Integer): TArg;
  public
    procedure Load(tx: TJsonValue);
    function  isEvent(const name: string): Boolean;
    property  BlockNumber: BigInteger read FBlockNumber;
    property  Topic[idx: Integer]: TArg read GetTopic;
    property  Data: TTuple read FData;
  end;

type
  PLog = ^TLog;

type
  TAsyncLog = reference to procedure(log: TLog);

function get(client: TWeb3; address: TAddress; callback: TAsyncLog): ITask;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  // web3
  web3.eth,
  web3.json,
  web3.json.rpc,
  web3.utils;

{ TLog }

function TLog.GetTopic(idx: Integer): TArg;
begin
  Result := FTopics[idx];
end;

procedure TLog.Load(tx: TJsonValue);
var
  tpcs: TJsonArray;
  tpc : Integer;
  buf : TBytes;
  arg : TArg;
  last: PArg;
begin
  FBlockNumber := web3.json.getPropAsStr(tx, 'blockNumber');
  // load the "topics"
  tpcs := web3.json.getPropAsArr(tx, 'topics');
  if Assigned(tpcs) then
    for tpc := 0 to Pred(tpcs.Count) do
    begin
      buf := web3.utils.fromHex(tpcs.Items[tpc].Value);
      if Length(buf) >= SizeOf(TArg) then
      begin
        Move(buf[0], arg[0], SizeOf(TArg));
        FTopics[tpc] := arg;
      end;
    end;
  // load the "data"
  buf := web3.utils.fromHex(web3.json.getPropAsStr(tx, 'data'));
  while Length(buf) >= SizeOf(TArg) do
  begin
    last := Data.Add;
    Move(buf[0], last[0], SizeOf(TArg));
    Delete(buf, 0, SizeOf(TArg));
  end;
end;

function TLog.isEvent(const name: string): Boolean;
var
  buf: TBytes;
  arg: TArg;
begin
  buf := web3.utils.sha3(web3.utils.toHex(name));
  Move(buf[0], arg[0], SizeOf(TArg));
  Result := CompareMem(@FTopics[0], @arg, SizeOf(TArg));
end;

{ TLogs }

type
  TLogs = TArray<TLog>;

{ TLogsHelper }

type
  TLogsHelper = record helper for TLogs
    function Add : PLog;
    function Last: PLog;
  end;

function TLogsHelper.Add: PLog;
begin
  SetLength(Self, Length(Self) + 1);
  Result := Last;
end;

function TLogsHelper.Last: PLog;
begin
  Result := nil;
  if Length(Self) > 0 then
    Result := @Self[High(Self)];
end;

{ private functions }

function getAsArr(client: TWeb3; fromBlock: BigInteger; address: TAddress): TJsonArray;
var
  &in : TJsonObject;
  &out: TJsonObject;
  arr : TJsonArray;
begin
  Result := nil;
  &in := web3.json.unmarshal(Format(
    '{"fromBlock": "%s", "toBlock": %s, "address": %s}', [
      web3.utils.toHex(fromBlock, [zeroAs0x0]),
      web3.json.quoteString(BLOCK_LATEST, '"'),
      web3.json.quoteString(string(address), '"')
    ]
  ));
  try
    &out := web3.json.rpc.send(client.URL, 'eth_getLogs', [&in]);
    if Assigned(&out) then
    try
      arr := web3.json.getPropAsArr(&out, 'result');
      if Assigned(arr) then
        Result := arr.Clone as TJsonArray;
    finally
      &out.Free;
    end;
  finally
    &in.Free;
  end;
end;

function getAsLog(client: TWeb3; fromBlock: BigInteger; address: TAddress): TLogs;
var
  arr : TJsonArray;
  itm : TJsonValue;
  last: PLog;
begin
  SetLength(Result, 0);
  arr := getAsArr(client, fromBlock, address);
  if Assigned(arr) then
  try
    for itm in arr do
    begin
      last := Result.Add;
      last.Load(itm);
    end;
  finally
    arr.Free;
  end;
end;

{ public functions }

function get(client: TWeb3; address: TAddress; callback: TAsyncLog): ITask;
begin
  Result := TTask.Create(procedure
  var
    bn  : BigInteger;
    log : TLog;
    logs: TLogs;
  begin
    bn := web3.eth.blockNumber(client);
    while TTask.CurrentTask.Status <> TTaskStatus.Canceled do
    begin
      logs := web3.eth.logs.getAsLog(client, bn, address);
      for log in logs do
      begin
        bn := BigInteger.Max(bn, log.BlockNumber.Succ);
        callback(log);
      end;
    end;
  end);
end;

end.
