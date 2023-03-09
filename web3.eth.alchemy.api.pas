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
    function IndexOf(const contract: TAddress): Integer;
    function Incoming(const address: TAddress): IAssetChanges;
    function Outgoing(const address: TAddress): IAssetChanges;
  end;

procedure simulate(
  const apiKey   : string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);

type
  TContractType = (
    Good,    // probably okay
    Airdrop, // probably an unwarranted airdrop. most of the owners are honeypots, or a significant chunk of the usual honeypot addresses own this token.
    Spam     // probably spam. this contract contains a lot of duplicate NFTs, or the contract lies about its own token supply. running totalSupply() on the contract is vastly different from the empirical number of tokens in circulation.
  );

procedure detect(
  const apiKey  : string;
  const chain   : TChain;
  const contract: TAddress;
  const callback: TProc<TContractType, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.Net.URLClient,
  System.Math,
  // web3
  web3.eth.alchemy,
  web3.eth.types,
  web3.http,
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
    function IndexOf(const contract: TAddress): Integer;
    function Incoming(const address: TAddress): IAssetChanges;
    function Outgoing(const address: TAddress): IAssetChanges;
  end;

function TAssetChanges.Item(const Index: Integer): IAssetChange;
begin
  Result := TAssetChange.Create(TJsonArray(FJsonValue)[Index]);
end;

function TAssetChanges.IndexOf(const contract: TAddress): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
      if Self.Item(Result).Contract.SameAs(contract) then
        EXIT;
  Result := -1;
end;

function TAssetChanges.Incoming(const address: TAddress): IAssetChanges;
begin
  var value := Self.FJsonValue.Clone as TJsonArray;
  try
    var index := 0;
    while index < value.Count do
    begin
      const change: IAssetChange = TAssetChange.Create(value[index]);
      if change.&To.SameAs(address) then
        Inc(index)
      else
        value.Remove(index);
    end;
    Result := TAssetChanges.Create(value);
  finally
    value.Free;
  end;
end;

function TAssetChanges.Outgoing(const address: TAddress): IAssetChanges;
begin
  var value := Self.FJsonValue.Clone as TJsonArray;
  try
    var index := 0;
    while index < value.Count do
    begin
      const change: IAssetChange = TAssetChange.Create(value[index]);
      if change.From.SameAs(address) then
        Inc(index)
      else
        value.Remove(index);
    end;
    Result := TAssetChanges.Create(value);
  finally
    value.Free;
  end;
end;

procedure alchemy_simulateAssetChanges(
  const apiKey   : string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<TJsonObject, IError>);
begin
  web3.eth.alchemy.endpoint(chain, apiKey)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(endpoint: string)
    begin
      const client = TWeb3.Create(chain.SetRPC(endpoint));
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
    end);
end;

procedure simulate(
  const apiKey   : string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  alchemy_simulateAssetChanges(apiKey, chain, from, &to, value, data, procedure(response: TJsonObject; err: IError)
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

procedure getTokenIDs(
  const apiKey: string;
  const chain: TChain;
  const contract: TAddress;
  const callback: TProc<TArray<string>, IError>);
type
  TPage = reference to procedure(const startWith: string; result: TArray<string>);
begin
  const get = procedure(
    const apiKey   : string;
    const chain    : TChain;
    const contract : TAddress;
    const startWith: string;
    const callback : TProc<TJsonValue, IError>)
  begin
    web3.eth.alchemy.endpoint(chain, apiKey, True)
      .ifErr(procedure(err: IError)
      begin
        callback(nil, err)
      end)
      .&else(procedure(endpoint: string)
      begin
        web3.http.get((function: string
          begin
            Result := Format('%s/getNFTsForCollection?contractAddress=%s', [endpoint, contract]);
            if startWith <> '' then
              Result := Result + '&startToken=' + startWith;
          end)(),
          [TNetHeader.Create('accept', 'application/json')],
          callback
        );
      end);
  end;

  var page: TPage;
  page := procedure(const startWith: string; result: TArray<string>)
  begin
    get(apiKey, chain, contract, startWith, procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback([], err);
        EXIT;
      end;
      const NFTs = getPropAsArr(response, 'nfts');
      if Assigned(NFTs) then for var NFT in NFTs do
      begin
        const id = getPropAsObj(NFT, 'id');
        if Assigned(id) then
        begin
          const tokenId = getPropAsStr(id, 'tokenId');
          if tokenId <> '' then
            Result := Result + [tokenId];
        end;
      end;
      const next = getPropAsStr(response, 'nextToken');
      if next <> '' then
        page(next, result)
      else
        callback(result, nil);
    end);
  end;

  page('', []);
end;

procedure isAirdrop(
  const apiKey  : string;
  const chain   : TChain;
  const contract: TAddress;
  const callback: TProc<Boolean, IError>);
begin
  web3.eth.alchemy.endpoint(chain, apiKey, True)
    .ifErr(procedure(err: IError)
    begin
      callback(False, err)
    end)
    .&else(procedure(endpoint: string)
    begin
      getTokenIDs(apiKey, chain, contract, procedure(TokenIDs: TArray<string>; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(False, err);
          EXIT;
        end;

        var get: TProc<Integer>;
        get := procedure(index: Integer)
        begin
          if index >= Length(TokenIDs) then
            callback(False, nil)
          else
            web3.http.get(
              Format('%s/isAirdrop?contractAddress=%s&tokenId=%s', [endpoint, contract, TokenIDs[index]]),
              [TNetHeader.Create('accept', 'application/json')],
              procedure(response: TJsonValue; err: IError)
              begin
                if Assigned(response) and (response is TJsonTrue) then
                  callback(True, nil)
                else
                  get(index + 1);
              end
            );
        end;

        get(0);
      end);
    end);
end;

procedure isSpam(
  const apiKey  : string;
  const chain   : TChain;
  const contract: TAddress;
  const callback: TProc<TJsonValue, IError>);
begin
  web3.eth.alchemy.endpoint(chain, apiKey, True)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(endpoint: string)
    begin
      web3.http.get(
        Format('%s/isSpamContract?contractAddress=%s', [endpoint, contract]),
        [TNetHeader.Create('accept', 'application/json')],
        callback
      );
    end);
end;

procedure detect(
  const apiKey  : string;
  const chain   : TChain;
  const contract: TAddress;
  const callback: TProc<TContractType, IError>);
begin
  isAirdrop(apiKey, chain, contract, procedure(response: Boolean; err: IError)
  begin
    if response then
      callback(Airdrop, nil)
    else
      isSpam(apiKey, chain, contract, procedure(response: TJsonValue; err: IError)
      begin
        if Assigned(response) and (response is TJsonTrue) then
          callback(Spam, nil)
        else
          callback(Good, err);
      end);
  end);
end;

end.
