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
begin
  Result := tokens('https://tokens.uniswap.org', procedure(tokens: TArray<IToken>; err: IError)
  begin
    if Assigned(err) or not Assigned(tokens) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var result: TArray<IToken>;
    for var token in tokens do
      if token.ChainId = chain.Id then
      begin
        SetLength(result, Length(result) + 1);
        result[Length(Result) - 1] := token;
      end;
    callback(result, nil);
  end);
end;

end.
