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
  TAsyncResponse   = reference to procedure(resp: IHttpResponse; err: IError);
  TAsyncJsonObject = reference to procedure(resp: TJsonObject;   err: IError);
  TAsyncJsonArray  = reference to procedure(resp: TJsonArray;    err: IError);

{---------------------------- async function calls ----------------------------}

function get(const URL: string; callback: TAsyncResponse)  : IAsyncResult; overload;
function get(const URL: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function get(const URL: string; callback: TAsyncJsonArray) : IAsyncResult; overload;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncResponse): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject): IAsyncResult; overload;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncResponse): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject): IAsyncResult; overload;

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
  out output: TJsonObject): Boolean; overload;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3.json;

{---------------------------- async function calls ----------------------------}

function get(const URL: string; callback: TAsyncResponse): IAsyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
        begin
          callback(resp, nil);
          EXIT;
        end;
        callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
      finally
        client.Free;
      end;
    end, URL);
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

function get(const URL: string; callback: TAsyncJsonObject): IAsyncResult;
var
  obj: TJsonObject;
begin
  get(URL, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
  end);
end;

function get(const URL: string; callback: TAsyncJsonArray): IAsyncResult;
var
  arr: TJsonValue;
begin
  get(URL, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    arr := TJsonObject.ParseJsonValue(resp.ContentAsString(TEncoding.UTF8));
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
    callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
  end);
end;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncResponse): IAsyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
        begin
          callback(resp, nil);
          EXIT;
        end;
        callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
      finally
        client.Free;
      end;
    end, URL, source, nil, headers);
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  source   : TStream;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject): IAsyncResult;
var
  obj: TJsonObject;
begin
  post(URL, source, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
  end);
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncResponse): IAsyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
        begin
          callback(resp, nil);
          EXIT;
        end;
        callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
      finally
        client.Free;
      end;
    end, URL, source, nil, headers);
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TAsyncJsonObject): IAsyncResult;
var
  obj: TJsonObject;
begin
  post(URL, source, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
  end);
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
  out output: TJsonObject): Boolean;
var
  resp: IHttpResponse;
begin
  output := nil;
  Result := post(URL, source, headers, resp);
  if Result then
  begin
    output := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    Result := Assigned(output);
  end;
end;

end.
