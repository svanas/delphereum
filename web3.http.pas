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
  System.SysUtils,
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

{---------------------------- async function calls ----------------------------}

function get(
  const URL: string;
  headers  : TNetHeaders;
  callback : TProc<IHttpResponse, IError>;
  backoff  : Integer = 1): IAsyncResult; overload;
function get(
  const URL: string;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
  backoff  : Integer = 1): IAsyncResult; overload;
function get(
  const URL: string;
  headers  : TNetHeaders;
  callback : TProc<TJsonArray, IError>;
  backoff  : Integer = 1) : IAsyncResult; overload;

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TProc<IHttpResponse, IError>;
  backoff  : Integer = 1): IAsyncResult; overload;
function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
  backoff  : Integer = 1): IAsyncResult; overload;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TProc<IHttpResponse, IError>;
  backoff  : Integer = 1): IAsyncResult; overload;
function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
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
  System.Math,
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

function get(const URL: string; headers: TNetHeaders; callback: TProc<IHttpResponse, IError>; backoff: Integer): IAsyncResult;
begin
  try
    const client = THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try try
        const resp = THttpClient.EndAsyncHttp(aSyncResult);
        if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
        begin
          callback(resp, nil);
          EXIT;
        end;
        if resp.StatusCode = 429 then
        begin
          const retryAfter = Min(MAX_BACKOFF, (function: Integer
          begin
            Result := backoff;
            if resp.ContainsHeader('Retry-After') then
              Result := StrToIntDef(resp.HeaderValue['Retry-After'], 0);
          end)());
          if retryAfter > 0 then
          begin
            TThread.Sleep(retryAfter * 1000);
            get(URL, headers, callback, backoff * 2);
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
    end, URL, nil, headers);
  except
    on E: Exception do callback(nil, TError.Create(E.Message));
  end;
end;

function get(const URL: string; headers: TNetHeaders; callback: TProc<TJsonObject, IError>; backoff: Integer): IAsyncResult;
begin
  Result := get(URL, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const obj = web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

function get(const URL: string; headers: TNetHeaders; callback: TProc<TJsonArray, IError>; backoff: Integer): IAsyncResult;
begin
  Result := get(URL, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const arr = TJsonObject.ParseJsonValue(resp.ContentAsString(TEncoding.UTF8));
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
  end, backoff);
end;

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TProc<IHttpResponse, IError>;
  backoff  : Integer): IAsyncResult;
begin
  try
    const client = THttpClient.Create;
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try try
        const resp = THttpClient.EndAsyncHttp(aSyncResult);
        if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
        begin
          callback(resp, nil);
          EXIT;
        end;
        if resp.StatusCode = 429 then
        begin
          const retryAfter = Min(MAX_BACKOFF, (function: Integer
          begin
            Result := backoff;
            if resp.ContainsHeader('Retry-After') then
              Result := StrToIntDef(resp.HeaderValue['Retry-After'], 0);
          end)());
          if retryAfter > 0 then
          begin
            TThread.Sleep(retryAfter * 1000);
            post(URL, src, headers, callback, backoff * 2);
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
  except
    on E: Exception do callback(nil, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
  backoff  : Integer): IAsyncResult;
begin
  Result := post(URL, src, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const obj = web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TProc<IHttpResponse, IError>;
  backoff  : Integer): IAsyncResult;
begin
  try
    const client = THttpClient.Create;
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try try
        const resp = THttpClient.EndAsyncHttp(aSyncResult);
        if (resp.StatusCode >= 200) and (resp.StatusCode < 300) then
        begin
          callback(resp, nil);
          EXIT;
        end;
        if resp.StatusCode = 429 then
        begin
          const retryAfter = Min(MAX_BACKOFF, (function: Integer
          begin
            Result := backoff;
            if resp.ContainsHeader('Retry-After') then
              Result := StrToIntDef(resp.HeaderValue['Retry-After'], 0);
          end)());
          if retryAfter > 0 then
          begin
            TThread.Sleep(retryAfter * 1000);
            post(URL, source, headers, callback, backoff * 2);
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
  except
    on E: Exception do callback(nil, TError.Create(E.Message));
  end;
end;

function post(
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
  backoff  : Integer): IAsyncResult;
begin
  Result := post(URL, source, headers, procedure(resp: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const obj = web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(resp.StatusCode, resp.ContentAsString(TEncoding.UTF8)));
  end, backoff);
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
  const client = THttpClient.Create;
  try
    output := client.Post(URL, TStringStream.Create(src), nil, headers);
    Result := Assigned(output) and (output.StatusCode >= 200) and (output.StatusCode < 300);
    if (not Result) and Assigned(output) and (output.StatusCode = 429) then
    begin
      const retryAfter = Min(MAX_BACKOFF, (function(const output: IHttpResponse): Integer
      begin
        Result := backoff;
        if output.ContainsHeader('Retry-After') then
          Result := StrToIntDef(output.HeaderValue['Retry-After'], 0);
      end)(output));
      if retryAfter > 0 then
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
