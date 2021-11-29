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
  begin
    web3.http.get(request.endpoint, procedure(resp: TJsonObject; err: IError)
    begin
      request.callback(resp, err);
      Queue.Enter;
      try
        Queue.Delete(0, 1);
        if Queue.Length > 0 then
        begin
          TThread.Sleep(Ceil(1000 / FReqPerSec));
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
  begin
    web3.http.post(request.endpoint, request.body, request.headers, procedure(resp: TJsonObject; err: IError)
    begin
      request.callback(resp, err);
      Queue.Enter;
      try
        Queue.Delete(0, 1);
        if Queue.Length > 0 then
        begin
          TThread.Sleep(Ceil(1000 / FReqPerSec));
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
