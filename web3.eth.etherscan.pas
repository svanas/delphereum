{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.etherscan;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.json;

type
  IEtherscanError = interface(IError)
  ['{4AAD53A6-FBD8-4FAB-83F7-6FDE0524CE5C}']
    function Status: Integer;
  end;

  TEtherscanError = class(TError, IEtherscanError)
  private
    FStatus: Integer;
  public
    constructor Create(aStatus: Integer; aBody: TJsonValue);
    function Status: Integer;
  end;

  IErc20TransferEvent = interface
    function Hash: TTxHash;
    function From: TAddress;
    function &To: TAddress;
    function Contract: TAddress;
    function Value: BigInteger;
  end;

  TSymbolType = (UnknownSymbol, &Function, &Constructor, Fallback, Event);

  TStateMutability = (UnknownMutability, Pure, View, NonPayable, Payable);

  IContractSymbol = interface
    function Name: string;
    function &Type: TSymbolType;
    function Inputs: TJsonArray;
    function Outputs: TJsonArray;
    function StateMutability: TStateMutability;
  end;

  IContractABI = interface(IDeserializedArray<IContractSymbol>)
    function Contract: TAddress;
    function IndexOf(
      const Name: string;
      &Type     : TSymbolType;
      InputCount: Integer): Integer; overload;
    function IndexOf(
      const Name     : string;
      &Type          : TSymbolType;
      StateMutability: TStateMutability): Integer; overload;
    function IndexOf(
      const Name     : string;
      &Type          : TSymbolType;
      InputCount     : Integer;
      StateMutability: TStateMutability): Integer; overload;
  end;

  IEtherscan = interface
    procedure getBlockNumberByTimestamp(
      timestamp: TUnixDateTime;
      callback : TProc<BigInteger, IError>);
    procedure getErc20TransferEvents(
      address : TAddress;
      callback: TProc<IDeserializedArray<IErc20TransferEvent>, IError>);
    procedure getContractABI(
      contract: TAddress;
      callback: TProc<IContractABI, IError>);
    procedure getContractSourceCode(
      contract: TAddress;
      callback: TProc<string, IError>);
  end;

function create(chain: TChain; const apiKey: string): IEtherscan;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.NetEncoding,
  System.TypInfo,
  // web3
  web3.eth.types,
  web3.http.throttler;

function endpoint(chain: TChain): IResult<string>; overload;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok('https://api.etherscan.io/api?')
  else if chain = Goerli then
    Result := TResult<string>.Ok('https://api-goerli.etherscan.io/api?')
  else if chain = Optimism then
    Result := TResult<string>.Ok('https://api-optimistic.etherscan.io/api?')
  else if chain = OptimismGoerli then
    Result := TResult<string>.Ok('https://api-goerli-optimistic.etherscan.io/api?')
  else if chain = BNB then
    Result := TResult<string>.Ok('https://api.bscscan.com/api?')
  else if chain = BNB_test_net then
    Result := TResult<string>.Ok('https://api-testnet.bscscan.com/api?')
  else if chain = Polygon then
    Result := TResult<string>.Ok('https://api.polygonscan.com/api?')
  else if chain = PolygonMumbai then
    Result := TResult<string>.Ok('https://api-testnet.polygonscan.com/api?')
  else if chain = Fantom then
    Result := TResult<string>.Ok('https://api.ftmscan.com/api?')
  else if chain = Fantom_test_net then
    Result := TResult<string>.Ok('https://api-testnet.ftmscan.com/api?')
  else if chain = Arbitrum then
    Result := TResult<string>.Ok('https://api.arbiscan.io/api?')
  else if chain = ArbitrumGoerli then
    Result := TResult<string>.Ok('https://goerli.arbiscan.io/api?')
  else if chain = Sepolia then
    Result := TResult<string>.Ok('https://api-sepolia.etherscan.io/api?')
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

function endpoint(chain: TChain; const apiKey: string): IResult<string>; overload;
begin
  Result := endpoint(chain);
  if Result.IsOk and (apiKey <> '') then
    Result := TResult<string>.Ok(Format('%sapikey=%s&', [Result.Value, apiKey]));
end;

{------------------------------ TEtherscanError -------------------------------}

constructor TEtherscanError.Create(aStatus: Integer; aBody: TJsonValue);

  function msg: string;
  begin
    Result := 'an unknown error occurred';
    if Assigned(aBody) then
    begin
      Result := web3.json.getPropAsStr(aBody, 'message');
      if Result = 'NOTOK' then
        Result := web3.json.getPropAsStr(aBody, 'result');
    end;
  end;

begin
  inherited Create(msg);
  FStatus := aStatus;
end;

function TEtherscanError.Status: Integer;
begin
  Result := FStatus;
end;

{---------------------------- TErc20TransferEvent -----------------------------}

type
  TErc20TransferEvent = class(TDeserialized, IErc20TransferEvent)
  public
    function Hash: TTxHash;
    function From: TAddress;
    function &To: TAddress;
    function Contract: TAddress;
    function Value: BigInteger;
  end;

function TErc20TransferEvent.Hash: TTxHash;
begin
  Result := TTxHash(getPropAsStr(FJsonValue, 'hash'));
end;

function TErc20TransferEvent.From: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from'));
end;

function TErc20TransferEvent.&To: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'to'));
end;

function TErc20TransferEvent.Contract: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'contractAddress'));
end;

function TErc20TransferEvent.Value: BigInteger;
begin
  Result := getPropAsBigInt(FJsonValue, 'value');
end;

{---------------------------- TErc20TransferEvents ----------------------------}

type
  TErc20TransferEvents = class(TDeserializedArray<IErc20TransferEvent>)
  public
    function Item(const Index: Integer): IErc20TransferEvent; override;
  end;

function TErc20TransferEvents.Item(const Index: Integer): IErc20TransferEvent;
begin
  Result := TErc20TransferEvent.Create(TJsonArray(FJsonValue)[Index]);
end;

{------------------------------ TContractSymbol -------------------------------}

type
  TContractSymbol = class(TDeserialized, IContractSymbol)
  public
    function Name: string;
    function &Type: TSymbolType;
    function Inputs: TJsonArray;
    function Outputs: TJsonArray;
    function StateMutability: TStateMutability;
  end;

function TContractSymbol.Name: string;
begin
  Result := getPropAsStr(FJsonValue, 'name');
end;

function TContractSymbol.&Type: TSymbolType;
begin
  const S = getPropAsStr(FJsonValue, 'type');
  for Result := System.Low(TSymbolType) to High(TSymbolType) do
    if SameText(GetEnumName(TypeInfo(TSymbolType), Integer(Result)), S) then
      EXIT;
  Result := UnknownSymbol;
end;

function TContractSymbol.Inputs: TJsonArray;
begin
  Result := getPropAsArr(FJsonValue, 'inputs');
end;

function TContractSymbol.Outputs: TJsonArray;
begin
  Result := getPropAsArr(FJsonValue, 'outputs');
end;

function TContractSymbol.StateMutability: TStateMutability;
begin
  const S = getPropAsStr(FJsonValue, 'stateMutability');
  for Result := System.Low(TStateMutability) to High(TStateMutability) do
    if SameText(GetEnumName(TypeInfo(TStateMutability), Integer(Result)), S) then
      EXIT;
  Result := UnknownMutability;
end;

{-------------------------------- TContractABI --------------------------------}

type
  TContractABI = class(TDeserializedArray<IContractSymbol>, IContractABI)
  private
    FChain: TChain;
    FContract: TAddress;
  public
    function Chain: TChain;
    function Contract: TAddress;
    function Item(const Index: Integer): IContractSymbol; override;
    function IndexOf(
      const Name: string;
      &Type     : TSymbolType;
      InputCount: Integer): Integer; overload;
    function IndexOf(
      const Name     : string;
      &Type          : TSymbolType;
      StateMutability: TStateMutability): Integer; overload;
    function IndexOf(
      const Name     : string;
      &Type          : TSymbolType;
      InputCount     : Integer;
      StateMutability: TStateMutability): Integer; overload;
    constructor Create(aChain: TChain; aContract: TAddress; aJsonArray: TJsonArray); reintroduce;
  end;

constructor TContractABI.Create(aChain: TChain; aContract: TAddress; aJsonArray: TJsonArray);
begin
  inherited Create(aJsonArray);
  FChain    := aChain;
  FContract := aContract;
end;

function TContractABI.Chain: TChain;
begin
  Result := FChain;
end;

function TContractABI.Contract: TAddress;
begin
  Result := FContract;
end;

function TContractABI.Item(const Index: Integer): IContractSymbol;
begin
  Result := TContractSymbol.Create(TJsonArray(FJsonValue)[Index]);
end;

function TContractABI.IndexOf(
  const Name: string;
  &Type     : TSymbolType;
  InputCount: Integer): Integer;
begin
  const count = Self.Count;
  if count.IsOk then
    for Result := 0 to Pred(count.Value) do
    begin
      const Item = Self.Item(Result);
      if  (Item.Name = Name)
      and (Item.&Type = &Type)
      and (Item.Inputs.Count = InputCount) then
        EXIT;
    end;
  Result := -1;
end;

function TContractABI.IndexOf(
  const Name     : string;
  &Type          : TSymbolType;
  StateMutability: TStateMutability): Integer;
begin
  const count = Self.Count;
  if count.IsOk then
    for Result := 0 to Pred(count.Value) do
    begin
      const Item = Self.Item(Result);
      if  (Item.Name = Name)
      and (Item.&Type = &Type)
      and (Item.StateMutability = StateMutability) then
        EXIT;
    end;
  Result := -1;
end;

function TContractABI.IndexOf(
  const Name     : string;
  &Type          : TSymbolType;
  InputCount     : Integer;
  StateMutability: TStateMutability): Integer;
begin
  const count = Self.Count;
  if count.IsOk then
    for Result := 0 to Pred(count.Value) do
    begin
      const Item = Self.Item(Result);
      if  (Item.Name = Name)
      and (Item.&Type = &Type)
      and (Item.Inputs.Count = InputCount)
      and (Item.StateMutability = StateMutability) then
        EXIT;
    end;
  Result := -1;
end;

{--------------------------------- TEtherscan ---------------------------------}

type
  TEtherscan = class(TGetter, IEtherscan)
  private
    chain : TChain;
    apiKey: string;
  protected
    procedure get(
      const query: string;
      callback   : TProc<TJsonValue, IError>);
  public
    procedure getBlockNumberByTimestamp(
      timestamp: TUnixDateTime;
      callback : TProc<BigInteger, IError>);
    procedure getErc20TransferEvents(
      address : TAddress;
      callback: TProc<IDeserializedArray<IErc20TransferEvent>, IError>);
    procedure getContractABI(
      contract: TAddress;
      callback: TProc<IContractABI, IError>);
    procedure getContractSourceCode(
      contract: TAddress;
      callback: TProc<string, IError>);
  end;

function create(chain: TChain; const apiKey: string): IEtherscan;
begin
  const etherscan = (function: TEtherscan
  begin
    if apiKey <> '' then
      Result := TEtherscan.Create(5)   // 5 req / 1 sec
    else
      Result := TEtherscan.Create(0.2) // 1 req / 5 sec
  end)();
  etherscan.chain  := chain;
  etherscan.apiKey := apiKey;
  Result := etherscan;
end;

procedure TEtherscan.get(
  const query: string;
  callback   : TProc<TJsonValue, IError>);
begin
  const URL = endpoint(Self.chain, TNetEncoding.URL.Encode(Self.apiKey));
  if URL.IsErr then
    callback(nil, URL.Error)
  else
    inherited Get(TGet.Create(URL.Value + query, [], callback));
end;

procedure TEtherscan.getBlockNumberByTimestamp(
  timestamp: TUnixDateTime;
  callback : TProc<BigInteger, IError>);
begin
  Self.get(Format('module=block&action=getblocknobytime&timestamp=%d&closest=before', [timestamp]),
  procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    const status = web3.json.getPropAsInt(response, 'status');
    if status = 0 then
      callback(0, TEtherscanError.Create(status, response))
    else
      callback(web3.json.getPropAsBigInt(response, 'result'), nil);
  end);
end;

procedure TEtherscan.getErc20TransferEvents(
  address : TAddress;
  callback: TProc<IDeserializedArray<IErc20TransferEvent>, IError>);
begin
  Self.get(Format('module=account&action=tokentx&address=%s&sort=desc', [address]),
  procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const status = web3.json.getPropAsInt(response, 'status');
    if status = 0 then
    begin
      callback(nil, TEtherscanError.Create(status, response));
      EXIT;
    end;
    const &array = web3.json.getPropAsArr(response, 'result');
    if not Assigned(&array) then
    begin
      callback(nil, TEtherscanError.Create(status, nil));
      EXIT;
    end;
    callback(TErc20TransferEvents.Create(&array), nil);
  end);
end;

procedure TEtherscan.getContractABI(
  contract: TAddress;
  callback: TProc<IContractABI, IError>);
begin
  Self.get(Format('module=contract&action=getabi&address=%s', [contract]),
  procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const status = web3.json.getPropAsInt(response, 'status');
    if status = 0 then
    begin
      callback(nil, TEtherscanError.Create(status, response));
      EXIT;
    end;
    const &result = unmarshal(web3.json.getPropAsStr(response, 'result'));
    if not Assigned(&result) then
    begin
      callback(nil, TEtherscanError.Create(status, nil));
      EXIT;
    end;
    try
      callback(TContractABI.Create(Self.chain, contract, TJsonArray(&result)), nil);
    finally
      &result.Free;
    end;
  end);
end;

procedure TEtherscan.getContractSourceCode(
  contract: TAddress;
  callback: TProc<string, IError>);
begin
  Self.get(Format('module=contract&action=getsourcecode&address=%s', [contract]),
  procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;
    const status = web3.json.getPropAsInt(response, 'status');
    if status = 0 then
    begin
      callback('', TEtherscanError.Create(status, response));
      EXIT;
    end;
    const &result = unmarshal(web3.json.getPropAsStr(response, 'result'));
    if not Assigned(&result) then
    begin
      callback('', TEtherscanError.Create(status, nil));
      EXIT;
    end;
    try
      if &result is TJsonArray then
      begin
        const &array = TJsonArray(&result);
        if &array.Count > 0 then
        begin
          callback(web3.json.getPropAsStr(&array[0], 'SourceCode'), nil);
          EXIT;
        end;
      end;
      callback('', TEtherscanError.Create(status, nil));
    finally
      &result.Free;
    end;
  end);
end;

end.
