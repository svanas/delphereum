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
  System.SysUtils,
  System.Types,
  // web3
  web3,
  web3.eth.types;

type
  IToken = interface
    function ChainId: Integer;
    function Address: TAddress;
    function Name: string;
    function Symbol: string;
    function Decimals: Integer;
    function LogoURI: string;
    procedure Balance(client: IWeb3; owner: TAddress; callback: TAsyncQuantity);
  end;

  TTokens = TArray<IToken>;

  TTokensHelper = record helper for TTokens
    procedure Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
    function IndexOf(address: TAddress): Integer;
  end;

  TAsyncTokens = reference to procedure(tokens: TTokens; err: IError);

function tokens(const source: string; callback: TAsyncJsonArray): IAsyncResult; overload;
function tokens(const source: string; callback: TAsyncTokens): IAsyncResult; overload;
function tokens(chain: TChain; callback: TAsyncTokens): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  // web3
  web3.eth.erc20,
  web3.http,
  web3.json;

{----------------------------------- TToken -----------------------------------}

type
  TToken = class(TInterfacedObject, IToken)
  private
    FChainId: Integer;
    FAddress: TAddress;
    FName: string;
    FSymbol: string;
    FDecimals: Integer;
    FLogoURI: string;
  public
    function ChainId: Integer;
    function Address: TAddress;
    function Name: string;
    function Symbol: string;
    function Decimals: Integer;
    function LogoURI: string;
    procedure Balance(client: IWeb3; owner: TAddress; callback: TAsyncQuantity);
    constructor Create(aJsonObject: TJsonObject);
  end;

constructor TToken.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FChainId := getPropAsInt(aJsonObject, 'chainId');
  FAddress := TAddress.New(getPropAsStr(aJsonObject, 'address'));
  FName := getPropAsStr(aJsonObject, 'name');
  FSymbol := getPropAsStr(aJsonObject, 'symbol');
  FDecimals := getPropAsInt(aJsonObject, 'decimals');
  FLogoURI := getPropAsStr(aJsonObject, 'logoURI');
end;

function TToken.ChainId: Integer;
begin
  Result := FChainId;
end;

function TToken.Address: TAddress;
begin
  Result := FAddress;
end;

function TToken.Name: string;
begin
  Result := FName;
end;

function TToken.Symbol: string;
begin
  Result := FSymbol;
end;

function TToken.Decimals: Integer;
begin
  Result := FDecimals;
end;

function TToken.LogoURI: string;
begin
  Result := FLogoURI;
end;

procedure TToken.Balance(client: IWeb3; owner: TAddress; callback: TAsyncQuantity);
begin
  var erc20 := TERC20.Create(client, Self.Address);
  try
    erc20.BalanceOf(owner, callback);
  finally
    erc20.Free;
  end;
end;

{------------------------------- TTokensHelper --------------------------------}

procedure TTokensHelper.Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
begin
  var next: TProc<TTokens, Integer>;

  next := procedure(tokens: TTokens; idx: Integer)
  begin
    if idx >= Length(tokens) then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    foreach(idx, procedure
    begin
      next(tokens, idx + 1);
    end);
  end;

  if Length(Self) = 0 then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  next(Self, 0);
end;

function TTokensHelper.IndexOf(address: TAddress): Integer;
begin
  for Result := 0 to Length(Self) - 1 do
    if Self[Result].Address.SameAs(address) then
      EXIT;
  Result := -1;
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
    var result: TTokens;
    SetLength(result, arr.Count);
    for var I := 0 to Pred(arr.Count) do
      result[I] := TToken.Create(arr[I] as TJsonObject);
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
    { Gnosis            } 'https://tokens.honeyswap.org',
    { Polygon           } 'https://unpkg.com/quickswap-default-token-list@latest/build/quickswap-default.tokenlist.json',
    { Polygon_test_net  } '',
    { Fantom            } '',
    { Fantom_test_net   } '',
    { Arbitrum          } 'https://bridge.arbitrum.io/token-list-42161.json',
    { Arbitrum_test_net } 'https://bridge.arbitrum.io/token-list-421611.json'
  );
begin
  // step #1: get the (multi-chain) Uniswap Labs List
  Result := tokens('https://tokens.uniswap.org', procedure(tokens1: TTokens; err1: IError)
  begin
    if Assigned(err1) or not Assigned(tokens1) then
    begin
      callback(nil, err1);
      EXIT;
    end;
    var result: TTokens;
    for var token1 in tokens1 do
      if token1.ChainId = chain.Id then
        result := result + [token1];
    // step #2: add tokens from a chain-specific token list (if any)
    if TOKEN_LIST[chain] = '' then
    begin
      callback(result, nil);
      EXIT;
    end;
    tokens(TOKEN_LIST[chain], procedure(tokens2: TTokens; err2: IError)
    begin
      if Assigned(err2) or not Assigned(tokens2) then
      begin
        callback(result, err2);
        EXIT;
      end;
      for var token2 in tokens2 do
        if (token2.ChainId = chain.Id) and (result.IndexOf(token2.Address) = -1) then
          result := result + [token2];
      callback(result, nil);
    end);
  end);
end;

end.
