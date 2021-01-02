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

unit web3.http.throttler;

{$I web3.inc}

interface

uses
  // Delphi
  System.Net.URLClient,
  // web3
  web3,
  web3.sync;

type
  TReqPerSec = Byte;

  TGet = record
    endpoint: string;
    callback: TAsyncJsonObject;
    constructor Create(const aURL: string; aCallback: TAsyncJsonObject);
  end;

  IGetter = interface
    procedure Get(const request: TGet);
  end;

  TGetter = class(TInterfacedObject, IGetter)
  strict private
    FQueue: ICriticalQueue<TGet>;
    FReqPerSec: TReqPerSec;
  strict protected
    function Queue: ICriticalQueue<TGet>;
  public
    procedure Get(const request: TGet);
    constructor Create(ReqPerSec: TReqPerSec);
  end;

  TPost = record
    endpoint: string;
    body    : string;
    headers : TNetHeaders;
    callback: TAsyncJsonObject;
    constructor Create(const aURL, aBody: string; aHeaders: TNetheaders; aCallback: TAsyncJsonObject);
  end;

  IThrottler = interface
    procedure Post(const request: TPost);
  end;

  TThrottler = class(TInterfacedObject, IThrottler)
  strict private
    FQueue: ICriticalQueue<TPost>;
    FReqPerSec: TReqPerSec;
  strict protected
    function Queue: ICriticalQueue<TPost>;
  public
    procedure Post(const request: TPost);
    constructor Create(ReqPerSec: TReqPerSec);
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.JSON,
  System.Math,
  System.SysUtils,
  // web3
  web3.http;

{ TGet }

constructor TGet.Create(const aURL: string; aCallback: TAsyncJsonObject);
begin
  Self.endpoint := aURL;
  Self.callback := aCallback;
end;

{ TGetter }

constructor TGetter.Create(ReqPerSec: TReqPerSec);
begin
  inherited Create;
  FReqPerSec := ReqPerSec;
end;

function TGetter.Queue: ICriticalQueue<TGet>;
begin
  if not Assigned(FQueue) then
    FQueue := TCriticalQueue<TGet>.Create;
  Result := FQueue;
end;

procedure TGetter.Get(const request: TGet);
var
  _get: TProc<TGet>;
begin
  _get := procedure(request: TGet)
  var
    wait: Integer;
  begin
    web3.http.get(request.endpoint, procedure(resp: TJsonObject; elapsed: Int64; err: IError)
    begin
      request.callback(resp, err);
      Queue.Enter;
      try
        Queue.Delete(0, 1);
        if Queue.Length > 0 then
        begin
          wait := Ceil(1000 / FReqPerSec);
          if elapsed < wait then
            TThread.Sleep(wait - elapsed);
          _get(Queue.First);
        end;
      finally
        Queue.Leave;
      end;
    end);
  end;
  Queue.Enter;
  try
    Queue.Add(request);
    if Queue.Length = 1 then
      _get(Queue.First);
  finally
    Queue.Leave;
  end;
end;

{ TPost }

constructor TPost.Create(const aURL, aBody: string; aHeaders: TNetHeaders; aCallback: TAsyncJsonObject);
begin
  Self.endpoint := aURL;
  Self.body     := aBody;
  Self.headers  := aHeaders;
  Self.callback := aCallback;
end;

{ TThrottler }

constructor TThrottler.Create(ReqPerSec: TReqPerSec);
begin
  inherited Create;
  FReqPerSec := ReqPerSec;
end;

function TThrottler.Queue: ICriticalQueue<TPost>;
begin
  if not Assigned(FQueue) then
    FQueue := TCriticalQueue<TPost>.Create;
  Result := FQueue;
end;

procedure TThrottler.Post(const request: TPost);
var
  _post: TProc<TPost>;
begin
  _post := procedure(request: TPost)
  var
    src : TStream;
    wait: Integer;
  begin
    src := TStringStream.Create(request.body);
    web3.http.post(request.endpoint, src, request.headers, procedure(resp: TJsonObject; elapsed: Int64; err: IError)
    begin
      try
        request.callback(resp, err);
      finally
        src.Free;
      end;
      Queue.Enter;
      try
        Queue.Delete(0, 1);
        if Queue.Length > 0 then
        begin
          wait := Ceil(1000 / FReqPerSec);
          if elapsed < wait then
            TThread.Sleep(wait - elapsed);
          _post(Queue.First);
        end;
      finally
        Queue.Leave;
      end;
    end);
  end;
  Queue.Enter;
  try
    Queue.Add(request);
    if Queue.Length = 1 then
      _post(Queue.First);
  finally
    Queue.Leave;
  end;
end;

end.
