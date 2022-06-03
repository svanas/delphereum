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

unit web3.eth.opensea;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3;

type
  INFT = interface
    function ChainId : Integer;
    function Address : TAddress;
    function TokenId : BigInteger;
    function Name    : string;
    function ImageURL: string;
    function Standard: TStandard;
  end;

  TNFTs = TArray<INFT>;

  TNFTsHelper = record helper for TNFTs
    procedure Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
    function Length: Integer;
  end;

  TAsyncNFTs = reference to procedure(NFTs: TNFTs; err: IError);

procedure NFTs(chain: TChain; const apiKey: string; owner: TAddress; callback: TAsyncJsonArray); overload;
procedure NFTs(chain: TChain; const apiKey: string; owner: TAddress; callback: TAsyncNFTs); overload;

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

{----------------------------------- TToken -----------------------------------}

type
  TNFT = class(TCustomDeserialized<TJsonObject>, INFT)
  private
    FChainId : Integer;
    FAddress : TAddress;
    FTokenId : BigInteger;
    FName    : string;
    FImageURL: string;
    FStandard: TStandard;
  public
    function ChainId : Integer;
    function Address : TAddress;
    function TokenId : BigInteger;
    function Name    : string;
    function ImageURL: string;
    function Standard: TStandard;
    constructor Create(aChainId: Integer; aJsonValue: TJsonObject); reintroduce;
  end;

constructor TNFT.Create(aChainId: Integer; aJsonValue: TJsonObject);
begin
  inherited Create(aJsonValue);

  FChainId  := aChainId;
  FTokenId  := getPropAsBigInt(aJsonValue, 'token_id');
  FName     := getPropAsStr(aJsonValue, 'name');
  FImageURL := getPropAsStr(aJsonValue, 'image_url');

  const contract = getPropAsObj(aJsonValue, 'asset_contract');
  if Assigned(contract) then
  begin
    FAddress  := TAddress.New(getPropAsStr(contract, 'address'));
    FStandard := TStandard.New(getPropAsStr(contract, 'schema_name'));
  end;
end;

function TNFT.ChainId: Integer;
begin
  Result := FChainId;
end;

function TNFT.Address: TAddress;
begin
  Result := FAddress;
end;

function TNFT.Name: string;
begin
  Result := FName;
end;

function TNFT.TokenId: BigInteger;
begin
  Result := FTokenId;
end;

function TNFT.ImageURL: string;
begin
  Result := FImageURL;
end;

function TNFT.Standard: TStandard;
begin
  Result := FStandard;
end;

{------------------------------- TTokensHelper --------------------------------}

procedure TNFTsHelper.Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
begin
  var next: TProc<TNFTs, Integer>;

  next := procedure(tokens: TNFTs; idx: Integer)
  begin
    if idx >= tokens.Length then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    foreach(idx, procedure
    begin
      next(tokens, idx + 1);
    end);
  end;

  if Self.Length = 0 then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  next(Self, 0);
end;

function TNFTsHelper.Length: Integer;
begin
  Result := System.Length(Self);
end;

{------------------------------ public functions ------------------------------}

function baseURL(chain: TChain): string;
begin
  if chain = Rinkeby then
    Result := 'https://rinkeby-api.opensea.io/api/v1/'
  else
    Result := 'https://api.opensea.io/api/v1/'
end;

procedure NFTs(chain: TChain; const apiKey: string; owner: TAddress; callback: TAsyncJsonArray); overload;
begin
  var result := TJsonArray.Create;

  var get: TProc<string, TJsonArray>;
  get := procedure(URL: string; result: TJsonArray)
  begin
    web3.http.get(URL, [TNetHeader.Create('X-API-KEY', apiKey)], procedure(obj: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(result, err);
        EXIT;
      end;

      const assets = getPropAsArr(obj, 'assets');
      for var asset in assets do
        result.Add(asset.Clone as TJsonObject);

      const next = getPropAsStr(obj, 'next');
      if not next.IsEmpty then
      begin
        if next.StartsWith('http', True) then
          get(next, result)
        else
          get(Format('%sassets?owner=%s&cursor=%s', [baseURL(chain), owner, next]), result);
        EXIT;
      end;

      callback(result, nil);
    end);
  end;

  get(baseURL(chain) + 'assets?owner=' + string(owner), result);
end;

procedure NFTs(chain: TChain; const apiKey: string; owner: TAddress; callback: TAsyncNFTs);
begin
  NFTs(chain, apiKey, owner, procedure(arr: TJsonArray; err: IError)
  begin
    if Assigned(err) or not Assigned(arr) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const result = (function: TNFTs
    begin
      SetLength(Result, arr.Count);
      for var I := 0 to Pred(arr.Count) do
        Result[I] := TNFT.Create(chain.Id, arr[I] as TJsonObject);
    end)();
    callback(result, nil);
  end);
end;

end.
