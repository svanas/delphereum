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
  System.SysUtils,
  // web3
  web3,
  web3.json.rpc;

type
  TJsonRpcHttps = class(TCustomJsonRpc, IJsonRpc)
  public
    function Call(
      const URL   : string;
      const method: string;
      const args  : array of const): IResult<TJsonObject>; overload;
    procedure Call(
      const URL     : string;
      const method  : string;
      const args    : array of const;
      const callback: TProc<TJsonObject, IError>); overload;
  end;

implementation

uses
  // Delphi
  System.Net.URLClient,
  // web3
  web3.http,
  web3.json;

{ TJsonRpcHttps }

function TJsonRpcHttps.Call(
  const URL   : string;
  const method: string;
  const args  : array of const): IResult<TJsonObject>;
begin
  const response = web3.http.post(URL, CreatePayload(method, args));
  if Assigned(response.Value) then
  try
    // did we receive an error? then translate that into an IError
    const error = web3.json.getPropAsObj(response.Value, 'error');
    if Assigned(error) then
      Result := TResult<TJsonObject>.Err(nil, TJsonRpcError.Create(
        web3.json.getPropAsInt(error, 'code'),
        web3.json.getPropAsStr(error, 'message')
      ))
    else
      Result := TResult<TJsonObject>.Ok(response.Value.Clone as TJsonObject);
    EXIT;
  finally
    response.Value.Free;
  end;
  Result := TResult<TJsonObject>.Err(nil, response.Error);
end;

procedure TJsonRpcHttps.Call(
  const URL     : string;
  const method  : string;
  const args    : array of const;
  const callback: TProc<TJsonObject, IError>);
begin
  web3.http.post(URL, CreatePayload(method, args), [TNetHeader.Create('Content-Type', 'application/json')], procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // did we receive an error?
    const error = web3.json.getPropAsObj(response, 'error');
    if Assigned(error) then
      callback(nil, TJsonRpcError.Create(
        web3.json.getPropAsInt(error, 'code'),
        web3.json.getPropAsStr(error, 'message')
      ))
    else
      if Assigned(response) and (response is TJsonObject) then
        // if we reached this far, then we have a valid response object
        callback(TJsonObject(response), nil)
      else
        callback(nil, TError.Create('not a JSON object'));
  end);
end;

end.
