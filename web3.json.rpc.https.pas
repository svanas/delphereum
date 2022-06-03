{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
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

unit web3.json.rpc.https;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  // web3
  web3,
  web3.http.throttler,
  web3.json.rpc;

type
  TJsonRpcHttps = class(TCustomJsonRpc, IJsonRpc)
  strict private
    FThrottler: IThrottler;
  public
    function Call(
      const URL   : string;
      const method: string;
      args        : array of const): TJsonObject; overload;
    procedure Call(
      const URL   : string;
      const method: string;
      args        : array of const;
      callback    : TAsyncJsonObject); overload;
    constructor Create; overload;
    constructor Create(const throttler: IThrottler); overload;
  end;

implementation

uses
  // Delphi
  System.Classes,
  System.Net.URLClient,
  // web3
  web3.http,
  web3.json;

{ TJsonRpcHttps }

constructor TJsonRpcHttps.Create;
begin
  inherited Create;
end;

constructor TJsonRpcHttps.Create(const throttler: IThrottler);
begin
  inherited Create;
  FThrottler := throttler;
end;

function TJsonRpcHttps.Call(
  const URL   : string;
  const method: string;
  args        : array of const): TJsonObject;
begin
  Result := nil;
  var resp: TJsonValue;
  web3.http.post(
    URL,
    CreatePayload(method, args),
    [TNetHeader.Create('Content-Type', 'application/json')],
    resp
  );
  if Assigned(resp) then
  try
    // did we receive an error? then translate that into an exception
    const error = web3.json.getPropAsObj(resp, 'error');
    if Assigned(error) then
      raise EJsonRpc.Create(
        web3.json.getPropAsInt(error, 'code'),
        web3.json.getPropAsStr(error, 'message')
      );
    Result := resp.Clone as TJsonObject;
  finally
    resp.Free;
  end;
end;

procedure TJsonRpcHttps.Call(
  const URL   : string;
  const method: string;
  args        : array of const;
  callback    : TAsyncJsonObject);
begin
  const handler: TAsyncJsonObject = procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // did we receive an error?
    const error = web3.json.getPropAsObj(resp, 'error');
    if Assigned(error) then
      callback(resp, TJsonRpcError.Create(
        web3.json.getPropAsInt(error, 'code'),
        web3.json.getPropAsStr(error, 'message')
      ))
    else
      // if we reached this far, then we have a valid response object
      callback(resp, nil);
  end;

  const payload = CreatePayload(method, args);
  const headers: TNetHeaders = [TNetHeader.Create('Content-Type', 'application/json')];

  if Assigned(FThrottler) then
  begin
    FThrottler.Post(TPost.Create(URL, payload, headers, handler));
    EXIT;
  end;

  web3.http.post(URL, payload, headers, handler);
end;

end.
