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

unit web3.graph;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3,
  web3.http;

type
  IGraphError = interface(IError)
  ['{46F0E07F-F47C-41BC-98BF-B8F7FA24AB91}']
  end;

  TGraphError = class(TError, IGraphError);

function execute(const URL, query: string; callback: TProc<TJsonObject, IError>): IAsyncResult;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.Net.URLClient,
  // web3
  web3.json;

function execute(const URL, query: string; callback: TProc<TJsonObject, IError>): IAsyncResult;
begin
  Result := web3.http.post(
    URL,
    query,
    [TNetHeader.Create('Content-Type', 'application/graphql')],
    procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      // did we receive an error?
      const errors = web3.json.getPropAsArr(response, 'errors');
      if Assigned(errors) and (errors.Count > 0) then
      begin
        callback(nil, TGraphError.Create(web3.json.getPropAsStr(errors.Items[0], 'message')));
        EXIT;
      end;
      if Assigned(response) and (response is TJsonObject) then
        // if we reached this far, then we have a valid response object
        callback(TJsonObject(response), nil)
      else
        callback(nil, TGraphError.Create('not a JSON object'));
    end
  );
end;

end.
