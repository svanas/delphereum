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
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  backoff  : Integer = 1): IResult<IHttpResponse>; overload;
function post(
  const URL: string;
  const src: string;
  backoff  : Integer = 1): IResult<TJsonValue>; overload;

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
        const response = THttpClient.EndAsyncHttp(aSyncResult);
        if (response.StatusCode >= 200) and (response.StatusCode < 300) then
        begin
          callback(response, nil);
          EXIT;
        end;
        if response.StatusCode = 429 then
        begin
          TThread.Sleep(Min(MAX_BACKOFF, (function: Integer
          begin
            if response.ContainsHeader('Retry-After') then
              Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
            else
              Result := backoff;
          end)()) * 1000);
          get(URL, headers, callback, backoff * 2);
          EXIT;
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

function get(const URL: string; headers: TNetHeaders; callback: TProc<TJsonObject, IError>; backoff: Integer): IAsyncResult;
begin
  Result := get(URL, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const obj = web3.json.unmarshal(response.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

function get(const URL: string; headers: TNetHeaders; callback: TProc<TJsonArray, IError>; backoff: Integer): IAsyncResult;
begin
  Result := get(URL, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const arr = TJsonObject.ParseJsonValue(response.ContentAsString(TEncoding.UTF8));
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
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
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
        const response = THttpClient.EndAsyncHttp(aSyncResult);
        if (response.StatusCode >= 200) and (response.StatusCode < 300) then
        begin
          callback(response, nil);
          EXIT;
        end;
        if response.StatusCode = 429 then
        begin
          TThread.Sleep(Min(MAX_BACKOFF, (function: Integer
          begin
            if response.ContainsHeader('Retry-After') then
              Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
            else
              Result := backoff;
          end)()) * 1000);
          post(URL, src, headers, callback, backoff * 2);
          EXIT;
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
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
  backoff  : Integer): IAsyncResult;
begin
  Result := post(URL, src, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const obj = web3.json.unmarshal(response.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
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
        const response = THttpClient.EndAsyncHttp(aSyncResult);
        if (response.StatusCode >= 200) and (response.StatusCode < 300) then
        begin
          callback(response, nil);
          EXIT;
        end;
        if response.StatusCode = 429 then
        begin
          TThread.Sleep(Min(MAX_BACKOFF, (function: Integer
          begin
            if response.ContainsHeader('Retry-After') then
              Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
            else
              Result := backoff;
          end)()) * 1000);
          post(URL, source, headers, callback, backoff * 2);
          EXIT;
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
  const URL: string;
  source   : TMultipartFormData;
  headers  : TNetHeaders;
  callback : TProc<TJsonObject, IError>;
  backoff  : Integer): IAsyncResult;
begin
  Result := post(URL, source, headers, procedure(response: IHttpResponse; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const obj = web3.json.unmarshal(response.ContentAsString(TEncoding.UTF8));
    if Assigned(obj) then
    try
      callback(obj as TJsonObject, nil);
      EXIT;
    finally
      obj.Free;
    end;
    callback(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
  end, backoff);
end;

{-------------------------- blocking function calls ---------------------------}

function post(
  const URL: string;
  const src: string;
  headers  : TNetHeaders;
  backoff  : Integer): IResult<IHttpResponse>;
begin
  const client = THttpClient.Create;
  try
    const response = client.Post(URL, TStringStream.Create(src), nil, headers);
    if not Assigned(response) then
    begin
      Result := TResult<IHttpResponse>.Err(nil, 'no response');
      EXIT;
    end;
    if response.StatusCode = 429 then
    begin
      TThread.Sleep(Min(MAX_BACKOFF, (function: Integer
      begin
        if response.ContainsHeader('Retry-After') then
          Result := StrToIntDef(response.HeaderValue['Retry-After'], backoff)
        else
          Result := backoff;
      end)()) * 1000);
      Result := post(URL, src, headers, backoff * 2);
      EXIT;
    end;
    if (response.StatusCode < 200) or (response.StatusCode >= 300) then
    begin
      Result := TResult<IHttpResponse>.Err(nil, THttpError.Create(response.StatusCode, response.ContentAsString(TEncoding.UTF8)));
      EXIT;
    end;
    Result := TResult<IHttpResponse>.Ok(response);
  finally
    client.Free;
  end;
end;

function post(
  const URL: string;
  const src: string;
  backoff  : Integer): IResult<TJsonValue>;
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
