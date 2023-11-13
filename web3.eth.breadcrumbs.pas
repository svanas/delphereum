{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2022 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.breadcrumbs;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3;

procedure sanctioned(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Boolean, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.Net.URLClient,
  // web3
  web3.eth.types,
  web3.http,
  web3.json;

procedure sanctioned(const apiKey: string; const chain: TChain; const address: TAddress; const callback: TProc<Boolean, IError>);
begin
  if (chain <> Ethereum) and (chain <> Goerli) and (chain <> Sepolia) and (chain <> Holesky) and (chain <> Polygon) then
  begin
    callback(False, TError.Create('%s not supported', [chain.Name]));
    EXIT;
  end;
  web3.http.post('https://apisanction.breadcrumbs.app/api/sanctioned_address',
    Format('[{"address":"%s","chain":"%s"}]', [address.ToChecksum, (function: string
    begin
      if chain = Polygon then
        Result := 'MATIC'
      else
        Result := 'ETH'
    end)()]),
    [TNetHeader.Create('Authorization', apiKey), TNetHeader.Create('Content-Type', 'application/json')],
    procedure(value: TJsonValue; err: IError)
    begin
      if Assigned(err) then
        callback(False, err)
      else
        if Assigned(value) and (value is TJsonArray) then
          callback((TJsonArray(value).Count > 0) and getPropAsBool(TJsonArray(value)[0], 'isSanctioned'), nil)
        else
          callback(False, TError.Create('not an array'));
    end);
end;

end.
