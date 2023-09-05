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
  System.JSON,
  System.SysUtils,
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

function vaults(const chain: TChain; const callback: TProc<TArray<IYearnVault>, IError>): IAsyncResult; overload;
function vaults(const chain: TChain; const callback: TProc<TJsonArray, IError>): IAsyncResult; overload;

function latest(const chain: TChain; const reserve: TAddress; const &type: TVaultType; const callback: TProc<IYearnVault, IError>): IAsyncResult;

implementation

uses
  // Delphi
  System.Generics.Collections,
  // web3
  web3.eth,
  web3.eth.types,
  web3.http,
  web3.json;

{--------------------------------- TMigration ---------------------------------}

type
  TMigration = class(TDeserialized, IMigration)
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
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'address'));
end;

{-------------------------------- TYearnVault ---------------------------------}

type
  TYearnVault = class(TDeserialized, IYearnVault)
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
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'address'));
end;

function TYearnVault.Token: TAddress;
begin
  Result := TAddress.Zero;
  const token = getPropAsObj(FJsonValue, 'token');
  if Assigned(token) then
    Result := TAddress.Create(getPropAsStr(token, 'address'));
end;

function TYearnVault.APY: Double;
begin
  Result := 0;
  const apy = getPropAsObj(FJsonValue, 'apy');
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
  const &type = getPropAsStr(FJsonValue, 'type');
  if &type = 'v1' then
    Result := v1
  else
    if &type = 'v2' then
      Result := v2;
end;

function TYearnVault.Migration: IMigration;
begin
  Result := nil;
  const migration = getPropAsObj(FJsonValue, 'migration');
  if Assigned(migration) then
    Result := TMigration.Create(migration);
end;

{------------------------------ public functions ------------------------------}

function vaults(const chain: TChain; const callback: TProc<TArray<IYearnVault>, IError>): IAsyncResult;
begin
  Result := vaults(chain, procedure(arr: TJsonArray; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const result = (function: TArray<IYearnVault>
    begin
      SetLength(Result, arr.Count);
      for var I := 0 to Pred(arr.Count) do
        Result[I] := TYearnVault.Create(arr[I] as TJsonObject);
    end)();
    callback(result, nil);
  end);
end;

function vaults(const chain: TChain; const callback: TProc<TJsonArray, IError>): IAsyncResult;
begin
  Result := web3.http.get(Format('https://api.yearn.fi/v1/chains/%d/vaults/all', [chain.Id]), [], procedure(value: TJsonValue; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      if Assigned(value) and (value is TJsonArray) then
        callback(TJsonArray(value), err)
      else
        callback(nil, TError.Create('not an array'));
  end);
end;

function latest(const chain: TChain; const reserve: TAddress; const &type: TVaultType; const callback: TProc<IYearnVault, IError>): IAsyncResult;
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
        const migration = vault.Migration;
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
