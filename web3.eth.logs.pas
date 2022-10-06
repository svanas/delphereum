{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.logs;

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
  TLog = record
  private
    FBlockNumber: BigInteger;
    FTopics     : TTopics;
    FData       : TTuple;
    function  GetTopic(idx: Integer): TArg;
    procedure Load(tx: TJsonValue);
  public
    function  isEvent(const name: string): Boolean;
    property  BlockNumber: BigInteger read FBlockNumber;
    property  Topic[idx: Integer]: TArg read GetTopic;
    property  Data: TTuple read FData;
  end;

  PLog = ^TLog;

  TStatus = (Idle, Running, Paused, Stopped);

  ILogger = interface
  ['{C2F29D30-00FC-4598-BEF4-59B65A9F55B5}']
    procedure Pause;
    procedure Start;
    function Status: TStatus;
    procedure Stop;
    procedure Wait;
  end;

function get(client: IWeb3; address: TAddress; callback: TProc<PLog, IError>): ILogger;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.Threading,
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
begin
  FBlockNumber := web3.json.getPropAsStr(tx, 'blockNumber');
  // load the "topics"
  const tpcs = web3.json.getPropAsArr(tx, 'topics');
  if Assigned(tpcs) then
    for var tpc := 0 to Pred(tpcs.Count) do
    begin
      const buf = web3.utils.fromHex(tpcs.Items[tpc].Value);
      if Length(buf) >= SizeOf(TArg) then
      begin
        var arg: TArg;
        Move(buf[0], arg.Inner[0], SizeOf(TArg));
        FTopics[tpc] := arg;
      end;
    end;
  // load the "data"
  var buf := web3.utils.fromHex(web3.json.getPropAsStr(tx, 'data'));
  while Length(buf) >= SizeOf(TArg) do
  begin
    const last = Data.Add;
    Move(buf[0], last^.Inner[0], SizeOf(TArg));
    Delete(buf, 0, SizeOf(TArg));
  end;
end;

function TLog.isEvent(const name: string): Boolean;
begin
  const buf = web3.utils.sha3(web3.utils.toHex(name));
  var arg: TArg;
  Move(buf[0], arg.Inner[0], SizeOf(TArg));
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

function getAsArr(client: IWeb3; fromBlock: BigInteger; address: TAddress): IResult<TJsonArray>;
begin
  const request = web3.json.unmarshal(Format(
    '{"fromBlock": "%s", "toBlock": %s, "address": %s}', [
      web3.utils.toHex(fromBlock, [zeroAs0x0]),
      web3.json.quoteString(BLOCK_LATEST, '"'),
      web3.json.quoteString(string(address), '"')
    ]
  )) as TJsonObject;
  try
    const response = client.Call('eth_getLogs', [request]);
    if Assigned(response.Value) then
    try
      const arr = web3.json.getPropAsArr(response.Value, 'result');
      if Assigned(arr) then
      begin
        Result := TResult<TJsonArray>.Ok(arr.Clone as TJsonArray);
        EXIT;
      end;
    finally
      response.Value.Free;
    end;
    Result := TResult<TJsonArray>.Err(nil, response.Error);
  finally
    request.Free;
  end;
end;

function getAsLog(client: IWeb3; fromBlock: BigInteger; address: TAddress): IResult<TLogs>;
begin
  const arr = getAsArr(client, fromBlock, address);
  if Assigned(arr.Value) then
  try
    var logs: TLogs := [];
    try
      for var itm in arr.Value do
      begin
        const last = logs.Add;
        last.Load(itm);
      end;
    finally
      Result := TResult<TLogs>.Ok(logs);
    end;
    EXIT;
  finally
    arr.Value.Free;
  end;
  Result := TResult<TLogs>.Err([], arr.Error);
end;

{ public functions }

type
  TLogger = class(TTask, ILogger)
  strict private
    FPaused : Boolean;
    FStopped: Boolean;
  public
    constructor Create(const Proc: TProc);
    procedure Pause;
    procedure Start;
    function Status: TStatus;
    procedure Stop;
    procedure Wait;
  end;

constructor TLogger.Create(const Proc: TProc);
begin
  inherited Create(nil, TNotifyEvent(nil), Proc, TThreadPool.Default, nil);
end;

procedure TLogger.Pause;
begin
  case Self.Status of
    Idle   : raise EInvalidOperation.Create('Cannot pause a logger that is not running');
    Running: FPaused := True;
    Paused : { nothing };
    Stopped: raise EInvalidOperation.Create('Cannot pause a logger that has already stopped');
  end;
end;

procedure TLogger.Start;
begin
  case Self.Status of
    Idle   : inherited Start;
    Running: { nothing };
    Paused : FPaused := False;
    Stopped: raise EInvalidOperation.Create('Cannot start a logger that has already stopped');
  end;
end;

function TLogger.Status: TStatus;
begin
  Result := Idle;
  if FStopped or (Self.GetStatus = TTaskStatus.Completed) then
    Result := Stopped
  else
    if Self.GetStatus in [TTaskStatus.WaitingToRun, TTaskStatus.Running] then
      if FPaused then
        Result := Paused
      else
        Result := Running;
end;

procedure TLogger.Stop;
begin
  case Self.Status of
    Idle   : raise EInvalidOperation.Create('Cannot stop a logger that is not running');
    Running: FStopped := True;
    Paused : FStopped := True;
    Stopped: { nothing };
  end;
end;

procedure TLogger.Wait;
begin
  if Self.Status = Paused then
    raise EInvalidOperation.Create('Cannot wait for a paused a logger to complete')
  else
    inherited Wait;
end;

function get(client: IWeb3; address: TAddress; callback: TProc<PLog, IError>): ILogger;
begin
  Result := TLogger.Create(procedure
  begin
    const latest = web3.eth.blockNumber(client);
    if latest.IsErr then
    begin
      callback(nil, latest.Error);
      EXIT;
    end;
    var blockNumber := latest.Value;
    while (TTask.CurrentTask as ILogger).Status <> Stopped do
    begin
      try
        TTask.CurrentTask.Wait(500);
      except end;
      if (TTask.CurrentTask as ILogger).Status <> Stopped then
      begin
        const logs = web3.eth.logs.getAsLog(client, blockNumber, address);
        if logs.IsErr then
           callback(nil, logs.Error)
        else
          for var log in logs.Value do
          begin
            blockNumber := BigInteger.Max(blockNumber, log.BlockNumber.Succ);
            if (TTask.CurrentTask as ILogger).Status <> Paused then
              callback(@log, nil);
          end;
      end;
    end;
  end);
end;

end.
