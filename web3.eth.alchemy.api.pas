{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2023 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.alchemy.api;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.json;

type
  TChangeType = (Approve, Transfer);

  IAssetChange = interface
    function Asset   : TAssetType;
    function Change  : TChangeType;
    function From    : TAddress;
    function &To     : TAddress;
    function Amount  : BigInteger;
    function Contract: TAddress;
    function Name    : string;
    function Symbol  : string;
    function Decimals: Integer;
    function Logo    : TURL;
    function Unscale : Double;
  end;

  IAssetChanges = interface(IDeserializedArray<IAssetChange>)
    function IndexOf(contract: TAddress): Integer;
  end;

procedure simulate(
  const apiKey: string;
  const chain : TChain;
  from, &to   : TAddress;
  value       : TWei;
  const data  : string;
  callback    : TProc<IAssetChanges, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.Math,
  // web3
  web3.eth.alchemy,
  web3.eth.types,
  web3.utils;

type
  TAssetChange = class(TDeserialized, IAssetChange)
  public
    function Asset   : TAssetType;
    function Change  : TChangeType;
    function From    : TAddress;
    function &To     : TAddress;
    function Amount  : BigInteger;
    function Contract: TAddress;
    function Name    : string;
    function Symbol  : string;
    function Decimals: Integer;
    function Logo    : TURL;
    function Unscale : Double;
  end;

function TAssetChange.Asset: TAssetType;
begin
  Result := TAssetType.Create(getPropAsStr(FJsonValue, 'assetType'));
end;

function TAssetChange.Change: TChangeType;
begin
  if SameText(getPropAsStr(FJsonValue, 'changeType'), 'TRANSFER') then
    Result := Transfer
  else
    Result := Approve;
end;

function TAssetChange.From: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from'));
end;

function TAssetChange.&To: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'to'));
end;

function TAssetChange.Amount: BigInteger;
begin
  Result := getPropAsBigInt(FJsonValue, 'rawAmount');
end;

function TAssetChange.Contract: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'contractAddress'));
end;

function TAssetChange.Name: string;
begin
  Result := getPropAsStr(FJsonValue, 'name');
end;

function TAssetChange.Symbol: string;
begin
  Result := getPropAsStr(FJsonValue, 'symbol');
end;

function TAssetChange.Decimals: Integer;
begin
  Result := getPropAsInt(FJsonValue, 'decimals');
end;

function TAssetChange.Logo: TURL;
begin
  Result := getPropAsStr(FJsonValue, 'logo');
end;

function TAssetChange.Unscale: Double;
begin
  Result := Self.Amount.AsDouble / Round(Power(10, Self.Decimals));
end;

type
  TAssetChanges = class(TDeserializedArray<IAssetChange>, IAssetChanges)
  public
    function Item(const Index: Integer): IAssetChange; override;
    function IndexOf(contract: TAddress): Integer;
  end;

function TAssetChanges.Item(const Index: Integer): IAssetChange;
begin
  Result := TAssetChange.Create(TJsonArray(FJsonValue)[Index]);
end;

function TAssetChanges.IndexOf(contract: TAddress): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
      if Self.Item(Result).Contract.SameAs(contract) then
        EXIT;
  Result := -1;
end;

procedure _simulate(
  const apiKey: string;
  const chain : TChain;
  from, &to   : TAddress;
  value       : TWei;
  const data  : string;
  callback    : TProc<TJsonObject, IError>);
begin
  const endpoint = web3.eth.alchemy.endpoint(chain, apiKey);
  if endpoint.IsErr then
  begin
    callback(nil, endpoint.Error);
    EXIT;
  end;
  const client = TWeb3.Create(chain.SetGateway(endpoint.Value));
  try
    const params = web3.json.unmarshal(Format(
      '{"from": %s, "to": %s, "value": %s, "data": %s}', [
        web3.json.quoteString(string(from), '"'),
        web3.json.quoteString(string(&to), '"'),
        web3.json.quoteString(toHex(value, [zeroAs0x0]), '"'),
        web3.json.quoteString(data, '"')]));
    try
      client.Call('alchemy_simulateAssetChanges', [params], procedure(response: TJsonObject; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          callback(web3.json.getPropAsObj(response, 'result'), nil);
      end);
    finally
      params.Free;
    end;
  finally
    client.Free;
  end;
end;

procedure simulate(
  const apiKey: string;
  const chain : TChain;
  from, &to   : TAddress;
  value       : TWei;
  const data  : string;
  callback    : TProc<IAssetChanges, IError>);
begin
  _simulate(apiKey, chain, from, &to, value, data, procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const error = web3.json.getPropAsObj(response, 'error');
    if Assigned(error) then
    begin
      callback(nil, TError.Create(web3.json.getPropAsStr(error, 'message', 'an unknown error occurred')));
      EXIT;
    end;
    const changes = web3.json.getPropAsArr(response, 'changes');
    if not Assigned(changes) then
    begin
      callback(nil, nil);
      EXIT;
    end;
    callback(TAssetChanges.Create(changes), nil);
  end);
end;

end.
