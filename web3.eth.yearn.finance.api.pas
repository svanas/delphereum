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

unit web3.eth.yearn.finance.api;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3;

type
  TVaultType = (vUnknown, v1, v2);

  IMigration = interface
    function Available: Boolean;
    function Address: TAddress;
  end;

  IYearnVault = interface
    function Address: TAddress;
    function Token: TAddress;
    function APY: Double;
    function Endorsed: Boolean;
    function Version: string;
    function &Type: TVaultType;
    function Migration: IMigration;
  end;

  TAsyncVault  = reference to procedure(const vault: IYearnVault; err: IError);
  TAsyncVaults = reference to procedure(vaults: TArray<IYearnVault>; err: IError);

function vaults(chain: TChain; callback: TAsyncVaults): IAsyncResult; overload;
function vaults(chain: TChain; callback: TAsyncJsonArray): IAsyncResult; overload;

function latest(chain: TChain; reserve: TAddress; &type: TVaultType; callback: TAsyncVault): IAsyncResult;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  // web3
  web3.eth,
  web3.eth.types,
  web3.http,
  web3.json;

{--------------------------------- TMigration ---------------------------------}

type
  TMigration = class(TDeserialized<TJsonObject>, IMigration)
  public
    function Available: Boolean;
    function Address: TAddress;
  end;

function TMigration.Available: Boolean;
begin
  Result := getPropAsBOOL(FJsonValue, 'available');
end;

function TMigration.Address: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'address'));
end;

{-------------------------------- TYearnVault ---------------------------------}

type
  TYearnVault = class(TDeserialized<TJsonObject>, IYearnVault)
  public
    function Address: TAddress;
    function Token: TAddress;
    function APY: Double;
    function Endorsed: Boolean;
    function Version: string;
    function &Type: TVaultType;
    function Migration: IMigration;
  end;

function TYearnVault.Address: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'address'));
end;

function TYearnVault.Token: TAddress;
begin
  Result := EMPTY_ADDRESS;
  var token := getPropAsObj(FJsonValue, 'token');
  if Assigned(token) then
    Result := TAddress.New(getPropAsStr(token, 'address'));
end;

function TYearnVault.APY: Double;
begin
  Result := 0;
  var apy := getPropAsObj(FJsonValue, 'apy');
  if Assigned(apy) then
     Result := getPropAsDouble(apy, 'net_apy', Result) * 100;
end;

function TYearnVault.Endorsed: Boolean;
begin
  Result := getPropAsBOOL(FJsonValue, 'endorsed');
end;

function TYearnVault.Version: string;
begin
  Result := getPropAsStr(FJsonValue, 'version');
end;

function TYearnVault.&Type: TVaultType;
begin
  Result := vUnknown;
  var &type := getPropAsStr(FJsonValue, 'type');
  if &type = 'v1' then
    Result := v1
  else
    if &type = 'v2' then
      Result := v2;
end;

function TYearnVault.Migration: IMigration;
begin
  Result := nil;
  var migration := getPropAsObj(FJsonValue, 'migration');
  if Assigned(migration) then
    Result := TMigration.Create(migration);
end;

{------------------------------ public functions ------------------------------}

function vaults(chain: TChain; callback: TAsyncVaults): IAsyncResult;
begin
  Result := vaults(chain, procedure(arr: TJsonArray; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var result: TArray<IYearnVault>;
    SetLength(result, arr.Count);
    for var I := 0 to Pred(arr.Count) do
      result[I] := TYearnVault.Create(arr[I] as TJsonObject);
    callback(result, nil);
  end);
end;

function vaults(chain: TChain; callback: TAsyncJsonArray): IAsyncResult;
begin
  Result := web3.http.get(Format('https://api.yearn.finance/v1/chains/%d/vaults/all', [chain.Id]), callback);
end;

function latest(chain: TChain; reserve: TAddress; &type: TVaultType; callback: TAsyncVault): IAsyncResult;
begin
  vaults(chain, procedure(vaults: TArray<IYearnVault>; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    for var vault in vaults do
      if vault.Endorsed and vault.Token.SameAs(reserve) and (vault.&Type = &type) then
      begin
        var migration := vault.Migration;
        if (Assigned(migration) and not migration.Available) or not Assigned(migration) then
        begin
          callback(vault, nil);
          EXIT;
        end;
      end;
    callback(nil, nil);
  end);
end;

end.
