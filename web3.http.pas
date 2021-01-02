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

unit web3.http;

{$I web3.inc}

interface

uses
  // Delphi
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.Mime,
  System.Net.URLClient,
  System.Types,
  // web3
  web3;

type
  IHttpError = interface(IError)
  ['{0E865DA6-C956-4914-909B-DC86E89A16D1}']
    function StatusCode: Integer;
  end;

  THttpError = class(TError, IHttpError)
  private
    FStatusCode: Integer;
  public
    constructor Create(aStatusCode: Integer; const aBody: string);
    function StatusCode: Integer;
  end;

  TAsyncResponse     = reference to procedure(resp: IHttpResponse; err: IError);
  TAsyncResponseEx   = reference to procedure(resp: IHttpResponse; elapsed: Int64; err: IError);
  TAsyncJsonObjectEx = reference to procedure(resp: TJsonObject;   elapsed: Int64; err: IError);
  TAsyncJsonArrayEx  = reference to procedure(resp: TJsonArray;    elapsed: Int64; err: IError);

{---------------------------- async function calls ----------------------------}

function get(
  const URL: string;
  callback : TAsyncResponse;
  timeout  : Integer = 60000): IAsyncResult; overload;
function get(
  const URL: string;
  callback : TAsyncJsonObject;
  timeout  : Integer = 60000): IAsyncResult; overload;
function get(
  const URL: string;
  callback : TAsyncJsonArray;
  timeout  : Integer = 60000) : IAsyncResult; overload;

function get(
  const URL: string;
  callback : TAsyncResponseEx;
  timeout  : Integer = 60000): IAsyncResult; overload;
function get(
  const URL: string;
  callback : TAsyncJsonObjectEx;
  timeout  : Integer = 60000): IAsyncResult; overload;
function get(
  const URL: string;
  callback : TAsyncJsonArrayEx;
  timeout  : Integer = 60000) : IAsyncResult; overload;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer = 60000): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer = 60000): IAsyncResult; overload;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncResponseEx;
  timeout  : Integer = 60000): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncJsonObjectEx;
  timeout  : Integer = 60000): IAsyncResult; overload;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer = 60000): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer = 60000): IAsyncResult; overload;

{-------------------------- blocking function calls ---------------------------}

function post(
  const URL : string;
  source    : TStream;
  headers   : TNetHeaders;
  out output: IHttpResponse): Boolean; overload;
function post(
  const URL : string;
  source    : TStream;
  headers   : TNetHeaders;
  out output: TJsonValue): Boolean; overload;

implementation

uses
  // Delphi
  System.DateUtils,
  System.Diagnostics,
  System.SysUtils,
  System.Threading,
  // web3
  web3.json,
  web3.sync;

{--------------------------------- THttpError ---------------------------------}

constructor THttpError.Create(aStatusCode: Integer; const aBody: string);
begin
  inherited Create(aBody);
  FStatusCode := aStatusCode;
end;

function THttpError.StatusCode: Integer;
begin
  Result := FStatusCode;
end;

{---------------------------- async function calls ----------------------------}

function get(const URL: string; callback: TAsyncResponse; timeout: Integer): IAsyncResult;
begin
  Result := get(
    URL,
    procedure(resp: IHttpResponse; elapsed: Int64; err: IError)
    begin
      callback(resp, err);
    end,
    timeout
  );
end;

function get(const URL: string; callback: TAsyncResponseEx; timeout: Integer): IAsyncResult;
var
  client: THttpClient;
  task  : ITask;
  timer : TStopWatch;
begin
  task := nil;
  try
    client := THttpClient.Create;

    if timeout > 0 then
    begin
      task := TTask.Create(procedure
      var
        started: TDatetime;
      begin
        started := System.SysUtils.Now;
        while TTask.CurrentTask.Status <> TTaskStatus.Canceled do
        begin
          try
            TTask.CurrentTask.Wait(500);
          except end;
          if  (TTask.CurrentTask.Status <> TTaskStatus.Canceled)
          and (MilliSecondsBetween(System.SysUtils.Now, started) > timeout) then
          begin
            callback(nil, timeout, TError.Create('web3.http.get() timed out'));
            EXIT;
          end;
        end;
      end, web3.sync.ThreadPool);
    end;

    timer := TStopWatch.StartNew;

    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    var
      resp: IHttpResponse;
    begin
      try
        if Assigned(task) then task.Cancel;
        try
          resp := THttpClient.EndAsyncHttp(aSyncResult);
          if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
          begin
            callback(resp, timer.ElapsedMilliseconds, nil);
            EXIT;
          end;
          callback(nil, timer.ElapsedMilliseconds, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
        except
          on E: Exception do callback(nil, timer.ElapsedMilliseconds, TError.Create(E.Message));
        end;
      finally
        client.Free;
      end;
    end, URL);

    if Assigned(task) then task.Start;
  except
    on E: Exception do callback(nil, 0, TError.Create(E.Message));
  end;
end;

function get(const URL: string; callback: TAsyncJsonObject; timeout: Integer): IAsyncResult;
begin
  Result := get(
    URL,
    procedure(resp: TJsonObject; elapsed: Int64; err: IError)
    begin
      callback(resp, err);
    end,
    timeout
  );
end;

function get(const URL: string; callback: TAsyncJsonObjectEx; timeout: Integer): IAsyncResult;
var
  obj: TJsonValue;
begin
  Result := get(URL, procedure(resp: IHttpResponse; elapsed: Int64; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, elapsed, err);
      EXIT;
    end;
    obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, elapsed, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, elapsed, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout);
end;

function get(const URL: string; callback: TAsyncJsonArray; timeout: Integer): IAsyncResult;
begin
  Result := get(
    URL,
    procedure(resp: TJsonArray; elapsed: Int64; err: IError)
    begin
      callback(resp, err);
    end,
    timeout
  );
end;

function get(const URL: string; callback: TAsyncJsonArrayEx; timeout: Integer): IAsyncResult;
var
  arr: TJsonValue;
begin
  Result := get(URL, procedure(resp: IHttpResponse; elapsed: Int64; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, elapsed, err);
      EXIT;
    end;
    arr := TJsonObject.ParseJsonValue(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(arr) then
    try
      if arr is TJsonArray then
      begin
        callback(TJsonArray(arr), elapsed, nil);
        EXIT;
      end;
    finally
      arr.Free;
    end;
    callback(nil, elapsed, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout);
end;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer): IAsyncResult;
begin
  Result := post(
    URL,
    source,
    headers,
    procedure(resp: IHttpResponse; elapsed: Int64; err: IError)
    begin
      callback(resp, err);
    end,
    timeout
  );
end;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncResponseEx;
  timeout  : Integer): IAsyncResult;
var
  client: THttpClient;
  task  : ITask;
  timer : TStopWatch;
begin
  task := nil;
  try
    client := THttpClient.Create;

    if timeout > 0 then
    begin
      task := TTask.Create(procedure
      var
        started: TDatetime;
      begin
        started := System.SysUtils.Now;
        while TTask.CurrentTask.Status <> TTaskStatus.Canceled do
        begin
          try
            TTask.CurrentTask.Wait(500);
          except end;
          if  (TTask.CurrentTask.Status <> TTaskStatus.Canceled)
          and (MilliSecondsBetween(System.SysUtils.Now, started) > timeout) then
          begin
            callback(nil, timeout, TError.Create('web3.http.post() timed out'));
            EXIT;
          end;
        end;
      end, web3.sync.ThreadPool);
    end;

    timer := TStopWatch.StartNew;

    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    var
      resp: IHttpResponse;
    begin
      try
        if Assigned(task) then task.Cancel;
        try
          resp := THttpClient.EndAsyncHttp(aSyncResult);
          if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
          begin
            callback(resp, timer.ElapsedMilliseconds, nil);
            EXIT;
          end;
          callback(nil, timer.ElapsedMilliseconds, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
        except
          on E: Exception do callback(nil, timer.ElapsedMilliseconds, TError.Create(E.Message));
        end;
      finally
        client.Free;
      end;
    end, URL, source, nil, headers);

    if Assigned(task) then task.Start;
  except
    on E: Exception do callback(nil, 0, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer): IAsyncResult;
begin
  Result := post(
    URL,
    source,
    headers,
    procedure(resp: TJsonObject; elapsed: Int64; err: IError)
    begin
      callback(resp, err);
    end,
    timeout
  );
end;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncJsonObjectEx;
  timeout  : Integer): IAsyncResult;
var
  obj: TJsonValue;
begin
  Result := post(URL, source, headers, procedure(resp: IHttpResponse; elapsed: Int64; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, elapsed, err);
      EXIT;
    end;
    obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, elapsed, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, elapsed, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout);
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer): IAsyncResult;
var
  client: THttpClient;
  task  : ITask;
begin
  task := nil;
  try
    client := THttpClient.Create;

    if timeout > 0 then
    begin
      task := TTask.Create(procedure
      var
        started: TDatetime;
      begin
        started := System.SysUtils.Now;
        while TTask.CurrentTask.Status <> TTaskStatus.Canceled do
        begin
          try
            TTask.CurrentTask.Wait(500);
          except end;
          if  (TTask.CurrentTask.Status <> TTaskStatus.Canceled)
          and (MilliSecondsBetween(System.SysUtils.Now, started) > timeout) then
          begin
            callback(nil, TError.Create('web3.http.post() timed out'));
            EXIT;
          end;
        end;
      end, web3.sync.ThreadPool);
    end;

    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    var
      resp: IHttpResponse;
    begin
      try
        if Assigned(task) then task.Cancel;
        try
          resp := THttpClient.EndAsyncHttp(aSyncResult);
          if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
          begin
            callback(resp, nil);
            EXIT;
          end;
          callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
        except
          on E: Exception do callback(nil, TError.Create(E.Message));
        end;
      finally
        client.Free;
      end;
    end, URL, source, nil, headers);

    if Assigned(task) then task.Start;
  except
    on E: Exception do callback(nil, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer): IAsyncResult;
var
  obj: TJsonValue;
begin
  Result := post(URL, source, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout);
end;

{-------------------------- blocking function calls ---------------------------}

function post(
  const URL : string;
  source    : TStream;
  headers   : TNetHeaders;
  out output: IHttpResponse): Boolean;
var
  client: THttpClient;
begin
  output := nil;
  client := THttpClient.Create;
  try
    output := client.Post(URL, source, nil, headers);
    Result := Assigned(output) and (output.StatusCode >= 200) and (output.StatusCode < 300);
  finally
    client.Free;
  end;
end;

function post(
  const URL : string;
  source    : TStream;
  headers   : TNetHeaders;
  out output: TJsonValue): Boolean;
var
  resp: IHttpResponse;
begin
  output := nil;
  Result := post(URL, source, headers, resp);
  if Result then
  begin
    output := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8)) as TJsonObject;
    Result := Assigned(output);
  end;
end;

end.
