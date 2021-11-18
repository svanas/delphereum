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

  TAsyncResponse = reference to procedure(resp: IHttpResponse; err: IError);

{---------------------------- async function calls ----------------------------}

function get(
  const URL: string;
  callback : TAsyncResponse;
  timeout  : Integer = 60000;
  backoff  : Integer = 1): IAsyncResult; overload;
function get(
  const URL: string;
  callback : TAsyncJsonObject;
  timeout  : Integer = 60000;
  backoff  : Integer = 1): IAsyncResult; overload;
function get(
  const URL: string;
  callback : TAsyncJsonArray;
  timeout  : Integer = 60000;
  backoff  : Integer = 1) : IAsyncResult; overload;

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer = 60000;
  backoff  : Integer = 1): IAsyncResult; overload;
function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer = 60000;
  backoff  : Integer = 1): IAsyncResult; overload;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer = 60000;
  backoff  : Integer = 1): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer = 60000;
  backoff  : Integer = 1): IAsyncResult; overload;

{-------------------------- blocking function calls ---------------------------}

function post(
  const URL : string;
  const src : string;
  headers   : TNetHeaders;
  out output: IHttpResponse;
  backoff   : Integer = 1): Boolean; overload;
function post(
  const URL : string;
  const src : string;
  headers   : TNetHeaders;
  out output: TJsonValue;
  backoff   : Integer = 1): Boolean; overload;

implementation

uses
  // Delphi
  System.DateUtils,
  System.SysUtils,
  System.Threading,
  // web3
  web3.json,
  web3.sync;

const
  MAX_BACKOFF = 32; // 32 seconds

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

function get(const URL: string; callback: TAsyncResponse; timeout, backoff: Integer): IAsyncResult;
begin
  var task: ITask := nil;
  try
    var client := THttpClient.Create;

    if timeout > 0 then
    begin
      task := TTask.Create(procedure
      begin
        var started := System.SysUtils.Now;
        while TTask.CurrentTask.Status <> TTaskStatus.Canceled do
        begin
          try
            TTask.CurrentTask.Wait(500);
          except end;
          if  (TTask.CurrentTask.Status <> TTaskStatus.Canceled)
          and (MilliSecondsBetween(System.SysUtils.Now, started) > timeout) then
          begin
            callback(nil, TError.Create('web3.http.get() timed out'));
            EXIT;
          end;
        end;
      end, web3.sync.ThreadPool);
    end;

    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        if Assigned(task) then task.Cancel;
        try
          var resp := THttpClient.EndAsyncHttp(aSyncResult);
          if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
          begin
            callback(resp, nil);
            EXIT;
          end;
          if resp.StatusCode = 429 then
          begin
            var retryAfter := backoff;
            if resp.ContainsHeader('Retry-After') then
              retryAfter := StrToIntDef(resp.HeaderValue['Retry-After'], 0);
            if (retryAfter > 0) and (retryAfter <= MAX_BACKOFF) then
            begin
              TThread.Sleep(retryAfter * 1000);
              get(URL, callback, timeout, backoff * 2);
              EXIT;
            end;
          end;
          callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
        except
          on E: Exception do callback(nil, TError.Create(E.Message));
        end;
      finally
        client.Free;
      end;
    end, URL);

    if Assigned(task) then task.Start;
  except
    on E: Exception do callback(nil, TError.Create(E.Message));
  end;
end;

function get(const URL: string; callback: TAsyncJsonObject; timeout, backoff: Integer): IAsyncResult;
begin
  Result := get(URL, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout, backoff);
end;

function get(const URL: string; callback: TAsyncJsonArray; timeout, backoff: Integer): IAsyncResult;
begin
  Result := get(URL, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var arr := TJsonObject.ParseJsonValue(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(arr) then
    try
      if arr is TJsonArray then
      begin
        callback(TJsonArray(arr), nil);
        EXIT;
      end;
    finally
      arr.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout, backoff);
end;

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer;
  backoff  : Integer): IAsyncResult;
begin
  var task: ITask := nil;
  try
    var client := THttpClient.Create;

    if timeout > 0 then
    begin
      task := TTask.Create(procedure
      begin
        var started := System.SysUtils.Now;
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
    begin
      try
        if Assigned(task) then task.Cancel;
        try
          var resp := THttpClient.EndAsyncHttp(aSyncResult);
          if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
          begin
            callback(resp, nil);
            EXIT;
          end;
          if resp.StatusCode = 429 then
          begin
            var retryAfter := backoff;
            if resp.ContainsHeader('Retry-After') then
              retryAfter := StrToIntDef(resp.HeaderValue['Retry-After'], 0);
            if (retryAfter > 0) and (retryAfter <= MAX_BACKOFF) then
            begin
              TThread.Sleep(retryAfter * 1000);
              post(URL, src, headers, callback, timeout, backoff * 2);
              EXIT;
            end;
          end;
          callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
        except
          on E: Exception do callback(nil, TError.Create(E.Message));
        end;
      finally
        client.Free;
      end;
    end, URL, TStringStream.Create(src), nil, headers);

    if Assigned(task) then task.Start;
  except
    on E: Exception do callback(nil, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject;
  timeout  : Integer;
  backoff  : Integer): IAsyncResult;
begin
  Result := post(URL, src, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout, backoff);
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncResponse;
  timeout  : Integer;
  backoff  : Integer): IAsyncResult;
begin
  var task: ITask := nil;
  try
    var client := THttpClient.Create;

    if timeout > 0 then
    begin
      task := TTask.Create(procedure
      begin
        var started := System.SysUtils.Now;
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
    begin
      try
        if Assigned(task) then task.Cancel;
        try
          var resp := THttpClient.EndAsyncHttp(aSyncResult);
          if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
          begin
            callback(resp, nil);
            EXIT;
          end;
          if resp.StatusCode = 429 then
          begin
            var retryAfter := backoff;
            if resp.ContainsHeader('Retry-After') then
              retryAfter := StrToIntDef(resp.HeaderValue['Retry-After'], 0);
            if (retryAfter > 0) and (retryAfter <= MAX_BACKOFF) then
            begin
              TThread.Sleep(retryAfter * 1000);
              post(URL, source, headers, callback, timeout, backoff * 2);
              EXIT;
            end;
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
  timeout  : Integer;
  backoff  : Integer): IAsyncResult;
begin
  Result := post(URL, source, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, timeout, backoff);
end;

{-------------------------- blocking function calls ---------------------------}

function post(
  const URL : string;
  const src : string;
  headers   : TNetHeaders;
  out output: IHttpResponse;
  backoff   : Integer): Boolean;
begin
  output := nil;
  var client := THttpClient.Create;
  try
    output := client.Post(URL, TStringStream.Create(src), nil, headers);
    Result := Assigned(output) and (output.StatusCode >= 200) and (output.StatusCode < 300);
    if (not Result) and Assigned(output) and (output.StatusCode = 429) then
    begin
      var retryAfter := backoff;
      if output.ContainsHeader('Retry-After') then
        retryAfter := StrToIntDef(output.HeaderValue['Retry-After'], 0);
      if (retryAfter > 0) and (retryAfter <= MAX_BACKOFF) then
      begin
        TThread.Sleep(retryAfter * 1000);
        Result := post(URL, src, headers, output, backoff * 2);
      end;
    end;
  finally
    client.Free;
  end;
end;

function post(
  const URL : string;
  const src : string;
  headers   : TNetHeaders;
  out output: TJsonValue;
  backoff   : Integer): Boolean;
begin
  output := nil;
  var resp: IHttpResponse := nil;
  Result := post(URL, src, headers, resp, backoff);
  if Result then
  begin
    output := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8)) as TJsonObject;
    Result := Assigned(output);
  end;
end;

end.
