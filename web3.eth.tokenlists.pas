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

unit web3.eth.tokenlists;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3;

type
  IToken = interface
    function ChainId: Integer;
    function Address: TAddress;
    function Name: string;
    function Symbol: string;
    function Decimals: Integer;
    function LogoURI: string;
  end;

  TAsyncTokens = reference to procedure(vaults: TArray<IToken>; err: IError);

function tokens(const source: string; callback: TAsyncJsonArray): IAsyncResult; overload;
function tokens(const source: string; callback: TAsyncTokens): IAsyncResult; overload;
function tokens(chain: TChain; callback: TAsyncTokens): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  // web3
  web3.eth.types,
  web3.http,
  web3.json;

{----------------------------------- TToken -----------------------------------}

type
  TToken = class(TInterfacedObject, IToken)
  private
    FJsonObject: TJsonObject;
  public
    function ChainId: Integer;
    function Address: TAddress;
    function Name: string;
    function Symbol: string;
    function Decimals: Integer;
    function LogoURI: string;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TToken.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TToken.Destroy;
begin
  if Assigned(FJsonObject) then FJsonObject.Free;
  inherited Destroy;
end;

function TToken.ChainId: Integer;
begin
  Result := getPropAsInt(FJsonObject, 'chainId');
end;

function TToken.Address: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonObject, 'address'));
end;

function TToken.Name: string;
begin
  Result := getPropAsStr(FJsonObject, 'name');
end;

function TToken.Symbol: string;
begin
  Result := getPropAsStr(FJsonObject, 'symbol');
end;

function TToken.Decimals: Integer;
begin
  Result := getPropAsInt(FJsonObject, 'decimals');
end;

function TToken.LogoURI: string;
begin
  Result := getPropAsStr(FJsonObject, 'logoURI');
end;

{------------------------------ public functions ------------------------------}

function tokens(const source: string; callback: TAsyncJsonArray): IAsyncResult;
begin
  Result := web3.http.get(source, procedure(obj: TJsonObject; err: IError)
  begin
    callback(getPropAsArr(obj, 'tokens'), err);
  end);
end;

function tokens(const source: string; callback: TAsyncTokens): IAsyncResult;
begin
  Result := tokens(source, procedure(arr: TJsonArray; err: IError)
  begin
    if Assigned(err) or not Assigned(arr) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var result: TArray<IToken>;
    SetLength(result, arr.Count);
    for var I := 0 to Pred(arr.Count) do
      result[I] := TToken.Create(arr[I].Clone as TJsonObject);
    callback(result, nil);
  end);
end;

function tokens(chain: TChain; callback: TAsyncTokens): IAsyncResult;
const
  TOKEN_LIST: array[TChain] of string = (
    { Ethereum          } 'https://tokens.coingecko.com/uniswap/all.json',
    { Ropsten           } '',
    { Rinkeby           } '',
    { Kovan             } '',
    { Goerli            } '',
    { Optimism          } 'https://static.optimism.io/optimism.tokenlist.json',
    { Optimism_test_net } '',
    { RSK               } '',
    { RSK_test_net      } '',
    { BSC               } 'https://tokens.pancakeswap.finance/pancakeswap-extended.json',
    { BSC_test_net      } '',
    { xDai              } '',
    { Polygon           } 'https://unpkg.com/quickswap-default-token-list@latest/build/quickswap-default.tokenlist.json',
    { Polygon_test_net  } '',
    { Fantom            } '',
    { Fantom_test_net   } '',
    { Arbitrum          } 'https://bridge.arbitrum.io/token-list-42161.json',
    { Arbitrum_test_net } ''
  );
begin
  // step #1: get the (multi-chain) Uniswap Labs List
  Result := tokens('https://tokens.uniswap.org', procedure(tokens1: TArray<IToken>; err1: IError)
  begin
    if Assigned(err1) or not Assigned(tokens1) then
    begin
      callback(nil, err1);
      EXIT;
    end;
    var result: TArray<IToken>;
    for var token in tokens1 do
      if token.ChainId = chain.Id then
        result := result + [token];
    // step #2: add tokens from a chain-specific token list (if any)
    if TOKEN_LIST[chain] = '' then
    begin
      callback(result, nil);
      EXIT;
    end;
    tokens(TOKEN_LIST[chain], procedure(tokens2: TArray<IToken>; err2: IError)
    begin
      if Assigned(err2) or not Assigned(tokens2) then
      begin
        callback(result, err2);
        EXIT;
      end;
      for var token in tokens2 do
        if token.ChainId = chain.Id then
          result := result + [token];
      callback(result, nil);
    end);
  end);
end;

end.
