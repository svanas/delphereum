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
  // web3
  web3,
  web3.eth.simulate;

// simulate transaction, return array of asset changes
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
  TContractTypes = set of TContractType;

// spam detection
procedure detect(
  const apiKey  : string;
  const chain   : TChain;
  const contract: TAddress;
  const checkFor: TContractTypes;
  const callback: TProc<TContractType, IError>);

// simulate transaction, return incoming assets that are honeypots (eg. you cannot sell)
procedure honeypots(
  const apiKey   : string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.Net.URLClient,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.eth.abi,
  web3.eth.alchemy,
  web3.eth.types,
  web3.http,
  web3.json,
  web3.utils;

{-------------------------------- TAssetChange --------------------------------}

type
  TAssetChange = class(TDeserialized, IAssetChange)
  public
    function Asset   : TAssetType;
    function Change  : TChangeType;
    function From    : TAddress;
    function &To     : TAddress;
    function Amount  : BigInteger;
    function Contract: TAddress;
    function Name    : IResult<string>;
    function Symbol  : IResult<string>;
    function Decimals: IResult<Integer>;
    function Logo    : IResult<TURL>;
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
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from', string(TAddress.Zero)));
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
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'contractAddress', string(TAddress.Zero)));
end;

function TAssetChange.Name: IResult<string>;
begin
  Result := TResult<string>.Ok(getPropAsStr(FJsonValue, 'name'));
end;

function TAssetChange.Symbol: IResult<string>;
begin
  Result := TResult<string>.Ok(getPropAsStr(FJsonValue, 'symbol'));
end;

function TAssetChange.Decimals: IResult<Integer>;
begin
  Result := TResult<Integer>.Ok(getPropAsInt(FJsonValue, 'decimals'));
end;

function TAssetChange.Logo: IResult<TURL>;
begin
  Result := TResult<string>.Ok(getPropAsStr(FJsonValue, 'logo'));
end;

{------------------------------- TAssetChanges --------------------------------}

type
  TAssetChanges = class(TCustomAssetChanges)
  strict protected
    class function CreateAssetChange(const aJsonObject: TJsonValue): IAssetChange; override;
    class function CreateAssetChanges(const aJsonArray: TJsonArray): IAssetChanges; override;
  end;

class function TAssetChanges.CreateAssetChange(const aJsonObject: TJsonValue): IAssetChange;
begin
  Result := TAssetChange.Create(aJsonObject);
end;

class function TAssetChanges.CreateAssetChanges(const aJsonArray: TJsonArray): IAssetChanges;
begin
  Result := TAssetChanges.Create(aJsonArray);
end;

{------------------------------ TRawTransaction -------------------------------}

type
  TRawTransaction = class(TCustomRawTransaction)
  public
    function Marshal: string; override;
  end;

function TRawTransaction.Marshal: string;
begin
  Result := Format('{"from": %s, "to": %s, "value": %s, "data": %s}', [
    web3.json.quoteString(string(Self.FFrom), '"'),
    web3.json.quoteString(string(Self.FTo), '"'),
    web3.json.quoteString(toHex(Self.FValue, [zeroAs0x0]), '"'),
    web3.json.quoteString(Self.FData, '"')
  ]);
end;

{---------------------------------- globals -----------------------------------}

procedure alchemy_simulateAssetChanges(
  const apiKey   : string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<TJsonObject, IError>);
begin
  web3.eth.alchemy.endpoint(chain, apiKey, core)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(endpoint: string)
    begin
      const client = TWeb3.Create(chain.SetRPC(endpoint));
      try
        const params = web3.json.unmarshal(Format('{"from": %s, "to": %s, "value": %s, "data": %s}', [
          web3.json.quoteString(string(from), '"'),
          web3.json.quoteString(string(&to), '"'),
          web3.json.quoteString(toHex(value, [zeroAs0x0]), '"'),
          web3.json.quoteString(data, '"')
        ]));
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
    web3.eth.alchemy.endpoint(chain, apiKey, nft)
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
  web3.eth.alchemy.endpoint(chain, apiKey, nft)
    .ifErr(procedure(err: IError)
    begin
      callback(False, err)
    end)
    .&else(procedure(endpoint: string)
    begin
      getTokenIDs(apiKey, chain, contract, procedure(TokenIDs: TArray<string>; err: IError)
      begin
        if Assigned(err) or (Length(TokenIDs) = 0) then
        begin
          callback(False, err);
          EXIT;
        end;

        // because it takes forever to go over each and every token ID, we limit ourselves to the first and the last
        if Length(TokenIDs) > 1 then
        begin
          Delete(TokenIDs, 1, Length(TokenIDs) - 2);
          SetLength(TokenIDs, 2);
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
  web3.eth.alchemy.endpoint(chain, apiKey, nft)
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
  const checkFor: TContractTypes;
  const callback: TProc<TContractType, IError>);
begin
  ( // step #1: check for unwarranted airdrop or skip this check
  procedure(callback: TProc<Boolean, IError>)
  begin
    if TContractType.Airdrop in checkFor then
      isAirdrop(apiKey, chain, contract, callback)
    else
      callback(False, nil);
  end)(procedure(response1: Boolean; err1: IError)
  begin
    if response1 and not Assigned(err1) then
      callback(TContractType.Airdrop, nil)
    else
      ( // step #2: check for spam contract or skip this check
      procedure(callback: TProc<Boolean, IError>)
      begin
        if not(TContractType.Spam in checkFor) then
          callback(False, nil)
        else
          isSpam(apiKey, chain, contract, procedure(response: TJsonValue; err: IError)
          begin
            callback(Assigned(response) and (response is TJsonTrue), err);
          end);
      end)(procedure(response2: Boolean; err2: IError)
      begin
        if response2 and not Assigned(err2) then
          callback(TContractType.Spam, nil)
        else
          callback(TContractType.Good, err2);
      end);
  end);
end;

procedure alchemy_simulateAssetChangesBundle(
  const apiKey  : string;
  const chain   : TChain;
  const tx1, tx2: IRawTransaction;
  const callback: TProc<TJsonArray, IError>);
begin
  web3.eth.alchemy.endpoint(chain, apiKey, core)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(endpoint: string)
    begin
      const client = TWeb3.Create(chain.SetRPC(endpoint));
      try
        const params = web3.json.unmarshal(Format('[%s, %s]', [tx1.Marshal, tx2.Marshal]));
        try
          client.Call('alchemy_simulateAssetChangesBundle', [params], procedure(response: TJsonObject; err: IError)
          begin
            if Assigned(err) then
              callback(nil, err)
            else
              callback(web3.json.getPropAsArr(response, 'result'), nil);
          end);
        finally
          params.Free;
        end;
      finally
        client.Free;
      end;
    end);
end;

procedure honeypots(
  const apiKey   : string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  // step #1: simulate asset changes
  simulate(apiKey, chain, from, &to, value, data, procedure(changes: IAssetChanges; err: IError)
  begin
    if Assigned(err) or not Assigned(changes) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // step #2: get incoming tokens
    const incoming = changes.Incoming(from);
    // step #3: simulate a sell for each and every incoming erc20
    var next: TProc<Integer, TProc>;
    next := procedure(incomingIndex: Integer; done: TProc)
    begin
      if (incoming = nil) or (incomingIndex >= incoming.Count) then
      begin
        done;
        EXIT;
      end;
      const change = incoming.Item(incomingIndex);
      if change.Asset <> erc20 then
      begin
        incoming.Delete(incomingIndex);
        next(incomingIndex, done);
        EXIT;
      end;
      alchemy_simulateAssetChangesBundle(apiKey, chain,
        TRawTransaction.Create(chain, from, &to, value, data),
        TRawTransaction.Create(
          chain,
          from,
          change.Contract,
          0,
          web3.eth.abi.encode('transfer(address,uint256)', ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', web3.utils.toHex(change.Amount)])
        ),
        procedure(response: TJsonArray; err: IError)
        begin
          if (err <> nil) or (response = nil) or (response.Count < 2) then
          begin
            callback(nil, err);
            EXIT;
          end;
          const error = web3.json.getPropAsObj(response[1], 'error');
          if Assigned(error) then
          begin
            callback(nil, TError.Create(web3.json.getPropAsStr(error, 'message', 'an unknown error occurred')));
            EXIT;
          end;
          const outgoing = TAssetChanges.Create(web3.json.getPropAsArr(response[1], 'changes')).Outgoing(from);
          if Assigned(outgoing) then
          begin
            const outgoingIndex = outgoing.IndexOf(change.Contract);
            if (outgoingIndex > -1) and (outgoing.Item(outgoingIndex).Amount = change.Amount) then
            begin
              incoming.Delete(incomingIndex);
              next(incomingIndex, done);
              EXIT;
            end;
          end;
          next(incomingIndex + 1, done);
        end);
    end;
    next(0, procedure
    begin
      callback(incoming, nil);
    end);
  end)
end;

end.
