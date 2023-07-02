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
    constructor Create(const aStatusCode: Integer; const aBody: string);
    function StatusCode: Integer;
  end;

{---------------------------- async function calls ----------------------------}

function get(
  const URL     : string;
  const headers : TNetHeaders;
  const callback: TProc<IHttpResponse, IError>;
  const backoff : Integer = 1): IAsyncResult; overload;
function get(
  const URL     : string;
  const headers : TNetHeaders;
  const callback: TProc<TJsonValue, IError>;
  const backoff : Integer = 1): IAsyncResult; overload;

function post(
  const URL     : string;
  const src     : string;
  const headers : TNetHeaders;
  const callback: TProc<IHttpResponse, IError>;
  const backoff : Integer = 1): IAsyncResult; overload;
function post(
  const URL     : string;
  const src     : string;
  const headers : TNetHeaders;
  const callback: TProc<TJsonValue, IError>;
  const backoff : Integer = 1): IAsyncResult; overload;

function post(
  const URL     : string;
  const source  : TMultipartFormData;
  const headers : TNetHeaders;
  const callback: TProc<IHttpResponse, IError>;
  const backoff : Integer = 1): IAsyncResult; overload;
function post(
  const URL     : string;
  const source  : TMultipartFormData;
  const headers : TNetHeaders;
  const callback: TProc<TJsonValue, IError>;
  const backoff : Integer = 1): IAsyncResult; overload;

{-------------------------- blocking function calls ---------------------------}

function get(
  const URL    : string;
  const headers: TNetHeaders;
  const backoff: Integer = 1): IResult<IHttpResponse>; overload;
function get(
  const URL    : string;
  const backoff: Integer = 1): IResult<TJsonValue>; overload;

function post(
  const URL    : string;
  const src    : string;
  const headers: TNetHeaders;
  const backoff: Integer = 1): IResult<IHttpResponse>; overload;
function post(
  const URL    : string;
  const src    : string;
  const backoff: Integer = 1): IResult<TJsonValue>; overload;

const
  MAX_BACKOFF_SECONDS = 32;

implementation

uses
  // web3
  web3.json,
  web3.sync;

{--------------------------------- THttpError ---------------------------------}

constructor THttpError.Create(const aStatusCode: Integer; const aBody: string);
begin
  inherited Create(aBody);
  FStatusCode := aStatusCode;
end;

function THttpError.StatusCode: Integer;
begin
  Result := FStatusCode;
end;

{---------------------------- async function calls ----------------------------}

function get(const URL: string; const headers: TNetHeaders; const callback: TProc<IHttpResponse, IError>; const backoff: Integer): IAsyncResult;
begin
  const client = THttpClient.Create;
  try
    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try try
        const response = THttpClient.EndAsyncHttp(aSyncResult);
        if (response.StatusCode >= 200) and (response.StatusCode < 300) then
        begin
          callback(response, nil);
          EXIT;
        end;
        if response.StatusCode = 429 then
        begin
          const retryAfter = (function: Integer
          begin
            if response.ContainsHeader('Retry-After') then
              Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
            else
              Result := backoff;
          end)();
          if retryAfter <= MAX_BACKOFF_SECONDS then
          begin
            TThread.Sleep(retryAfter * 1000);
            get(URL, headers, callback, backoff * 2);
            EXIT;
          end;
        end;
        callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
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

function get(const URL: string; const headers: TNetHeaders; const callback: TProc<TJsonValue, IError>; const backoff: Integer): IAsyncResult;
begin
  Result := get(URL, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const value = web3.json.unmarshal(response.ContentAsString(TEncoding.UTF8));
    if Assigned(value) then
    try
      callback(value, nil);
      EXIT;
    finally
      value.Free;
    end;
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

function post(
  const URL     : string;
  const src     : string;
  const headers : TNetHeaders;
  const callback: TProc<IHttpResponse, IError>;
  const backoff : Integer): IAsyncResult;
begin
  const client = THttpClient.Create;
  try
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try try
        const response = THttpClient.EndAsyncHttp(aSyncResult);
        if (response.StatusCode >= 200) and (response.StatusCode < 300) then
        begin
          callback(response, nil);
          EXIT;
        end;
        if response.StatusCode = 429 then
        begin
          const retryAfter = (function: Integer
          begin
            if response.ContainsHeader('Retry-After') then
              Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
            else
              Result := backoff;
          end)();
          if retryAfter <= MAX_BACKOFF_SECONDS then
          begin
            TThread.Sleep(retryAfter * 1000);
            post(URL, src, headers, callback, backoff * 2);
            EXIT;
          end;
        end;
        callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
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
  const URL     : string;
  const src     : string;
  const headers : TNetHeaders;
  const callback: TProc<TJsonValue, IError>;
  const backoff : Integer): IAsyncResult;
begin
  Result := post(URL, src, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const value = web3.json.unmarshal(response.ContentAsString(TEncoding.UTF8));
    if Assigned(value) then
    try
      callback(value, nil);
      EXIT;
    finally
      value.Free;
    end;
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

function post(
  const URL     : string;
  const source  : TMultipartFormData;
  const headers : TNetHeaders;
  const callback: TProc<IHttpResponse, IError>;
  const backoff : Integer): IAsyncResult;
begin
  const client = THttpClient.Create;
  try
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try try
        const response = THttpClient.EndAsyncHttp(aSyncResult);
        if (response.StatusCode >= 200) and (response.StatusCode < 300) then
        begin
          callback(response, nil);
          EXIT;
        end;
        if response.StatusCode = 429 then
        begin
          const retryAfter = (function: Integer
          begin
            if response.ContainsHeader('Retry-After') then
              Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
            else
              Result := backoff;
          end)();
          if retryAfter <= MAX_BACKOFF_SECONDS then
          begin
            TThread.Sleep(retryAfter * 1000);
            post(URL, source, headers, callback, backoff * 2);
            EXIT;
          end;
        end;
        callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
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
  const URL     : string;
  const source  : TMultipartFormData;
  const headers : TNetHeaders;
  const callback: TProc<TJsonValue, IError>;
  const backoff : Integer): IAsyncResult;
begin
  Result := post(URL, source, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const value = web3.json.unmarshal(response.ContentAsString(TEncoding.UTF8));
    if Assigned(value) then
    try
      callback(value, nil);
      EXIT;
    finally
      value.Free;
    end;
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

{-------------------------- blocking function calls ---------------------------}

function get(const URL: string; const headers: TNetHeaders; const backoff: Integer): IResult<IHttpResponse>;
begin
  const client = THttpClient.Create;
  try try
    const response = client.Get(URL, nil, headers);
    if not Assigned(response) then
    begin
      Result := TResult<IHttpResponse>.Err(nil, 'no response');
      EXIT;
    end;
    if response.StatusCode = 429 then
    begin
      const retryAfter = (function: Integer
      begin
        if response.ContainsHeader('Retry-After') then
          Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
        else
          Result := backoff;
      end)();
      if retryAfter <= MAX_BACKOFF_SECONDS then
      begin
        TThread.Sleep(retryAfter * 1000);
        Result := get(URL, headers, backoff * 2);
        EXIT;
      end;
    end;
    if (response.StatusCode < 200) or (response.StatusCode >= 300) then
    begin
      Result := TResult<IHttpResponse>.Err(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
      EXIT;
    end;
    Result := TResult<IHttpResponse>.Ok(response);
  except
    on E: Exception do Result := TResult<IHttpResponse>.Err(nil, TError.Create(E.Message));
  end;
  finally
    client.Free;
  end;
end;

function get(const URL: string; const backoff: Integer): IResult<TJsonValue>;
begin
  const response = get(URL, [TNetHeader.Create('Content-Type', 'application/json')], backoff);
  if Assigned(response.Value) then
  begin
    const value = web3.json.unmarshal(response.Value.ContentAsString(TEncoding.UTF8));
    if Assigned(value) then
    begin
      Result := TResult<TJsonValue>.Ok(value);
      EXIT;
    end;
  end;
  Result := TResult<TJsonValue>.Err(nil, response.Error);
end;

function post(
  const URL    : string;
  const src    : string;
  const headers: TNetHeaders;
  const backoff: Integer): IResult<IHttpResponse>;
begin
  const client = THttpClient.Create;
  try try
    const response = client.Post(URL, TStringStream.Create(src), nil, headers);
    if not Assigned(response) then
    begin
      Result := TResult<IHttpResponse>.Err(nil, 'no response');
      EXIT;
    end;
    if response.StatusCode = 429 then
    begin
      const retryAfter = (function: Integer
      begin
        if response.ContainsHeader('Retry-After') then
          Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
        else
          Result := backoff;
      end)();
      if retryAfter <= MAX_BACKOFF_SECONDS then
      begin
        TThread.Sleep(retryAfter * 1000);
        Result := post(URL, src, headers, backoff * 2);
        EXIT;
      end;
    end;
    if (response.StatusCode < 200) or (response.StatusCode >= 300) then
    begin
      Result := TResult<IHttpResponse>.Err(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
      EXIT;
    end;
    Result := TResult<IHttpResponse>.Ok(response);
  except
    on E: Exception do Result := TResult<IHttpResponse>.Err(nil, TError.Create(E.Message));
  end;
  finally
    client.Free;
  end;
end;

function post(
  const URL    : string;
  const src    : string;
  const backoff: Integer): IResult<TJsonValue>;
begin
  const response = post(URL, src, [TNetHeader.Create('Content-Type', 'application/json')], backoff);
  if Assigned(response.Value) then
  begin
    const value = web3.json.unmarshal(response.Value.ContentAsString(TEncoding.UTF8));
    if Assigned(value) then
    begin
      Result := TResult<TJsonValue>.Ok(value);
      EXIT;
    end;
  end;
  Result := TResult<TJsonValue>.Err(nil, response.Error);
end;

end.
