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
  web3.eth.types,
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
    constructor Create(aStatus: Integer; aBody: TJsonObject);
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
    function Chain: TChain;
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

procedure getBlockNumberByTimestamp(
  client      : IWeb3;
  timestamp   : TUnixDateTime;
  callback    : TProc<BigInteger, IError>); overload;
procedure getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TProc<BigInteger, IError>); overload;

procedure getErc20TransferEvents(
  client      : IWeb3;
  address     : TAddress;
  callback    : TProc<IDeserializedArray<IErc20TransferEvent>, IError>); overload;
procedure getErc20TransferEvents(
  chain       : TChain;
  address     : TAddress;
  const apiKey: string;
  callback    : TProc<IDeserializedArray<IErc20TransferEvent>, IError>); overload;

procedure getContractABI(
  client      : IWeb3;
  contract    : TAddress;
  callback    : TProc<IContractABI, IError>); overload;
procedure getContractABI(
  chain       : TChain;
  contract    : TAddress;
  const apiKey: string;
  callback    : TProc<IContractABI, IError>); overload;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.NetEncoding,
  System.TypInfo,
  // web3
  web3.http.throttler,
  web3.sync;

function endpoint(chain: TChain; const apiKey: string): IResult<string>;
const
  ENDPOINT: array[TChain] of string = (
    'https://api.etherscan.io/api?apikey=%s',                   // Ethereum
    'https://api-goerli.etherscan.io/api?apikey=%s',            // Goerli
    'https://api-optimistic.etherscan.io/api?apikey=%s',        // Optimism
    'https://api-goerli-optimistic.etherscan.io/api?apikey=%s', // OptimismGoerli
    '',                                                         // RSK
    '',                                                         // RSK_test_net
    'https://api.bscscan.com/api?apikey=%s',                    // BNB
    'https://api-testnet.bscscan.com/api?apikey=%s',            // BNB_test_net
    '',                                                         // Gnosis
    'https://api.polygonscan.com/api?apikey=%s',                // Polygon
    'https://api-testnet.polygonscan.com/api?apikey=%s',        // PolygonMumbai
    'https://api.ftmscan.com/api?apikey=%s',                    // Fantom
    'https://api-testnet.ftmscan.com/api?apikey=%s',            // Fantom_test_net
    'https://api.arbiscan.io/api?apikey=%s',                    // Arbitrum
    'https://api-testnet.arbiscan.io/api?apikey=%s',            // ArbitrumRinkeby
    'https://api-sepolia.etherscan.io/api?apikey=%s'            // Sepolia
  );
begin
  const URL = ENDPOINT[chain];
  if URL <> '' then
    Result := TResult<string>.Ok(Format(URL, [apiKey]))
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

{------------------------------ TEtherscanError -------------------------------}

constructor TEtherscanError.Create(aStatus: Integer; aBody: TJsonObject);

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
  TErc20TransferEvent = class(TDeserialized<TJsonObject>, IErc20TransferEvent)
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
  Result := TAddress.New(getPropAsStr(FJsonValue, 'from'));
end;

function TErc20TransferEvent.&To: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'to'));
end;

function TErc20TransferEvent.Contract: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'contractAddress'));
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
  Result := TErc20TransferEvent.Create(FJsonValue.Items[Index] as TJsonObject);
end;

{------------------------------ TContractSymbol -------------------------------}

type
  TContractSymbol = class(TDeserialized<TJsonObject>, IContractSymbol)
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
  Result := TContractSymbol.Create(FJsonValue.Items[Index] as TJsonObject);
end;

function TContractABI.IndexOf(
  const Name: string;
  &Type     : TSymbolType;
  InputCount: Integer): Integer;
begin
  for Result := 0 to Pred(Count) do
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
  for Result := 0 to Pred(Count) do
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
  for Result := 0 to Pred(Count) do
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

{------------------------------- ContractCache --------------------------------}

type
  IContractCache = interface(ICriticalThing)
    function  Get(Index: Integer): IContractABI;
    procedure Put(Index: Integer; const Item: IContractABI);
    function  Add(const Item: IContractABI): Integer;
    function  IndexOf(aChain: TChain; aContract: TAddress): Integer;
  end;

  TContractCache = class(TCriticalList, IContractCache)
  strict protected
    function  Get(Index: Integer): IContractABI;
    procedure Put(Index: Integer; const Item: IContractABI);
  public
    function  Add(const Item: IContractABI): Integer;
    function  IndexOf(aChain: TChain; aContract: TAddress): Integer;
    property  Items[Index: Integer]: IContractABI read Get write Put; default;
  end;

function TContractCache.Get(Index: Integer): IContractABI;
begin
  Result := IContractABI(inherited Get(Index));
end;

procedure TContractCache.Put(Index: Integer; const Item: IContractABI);
begin
  inherited Put(Index, Item);
end;

function TContractCache.Add(const Item: IContractABI): Integer;
begin
  Result := inherited Add(Item);
end;

function TContractCache.IndexOf(aChain: TChain; aContract: TAddress): Integer;
begin
  for Result := 0 to Pred(Count) do
    if (Items[Result].Chain = aChain) and (Items[Result].Contract = aContract) then
      EXIT;
  Result := -1;
end;

var
  _ContractCache: IContractCache = nil;

function ContractCache: IContractCache;
begin
  if not Assigned(_ContractCache) then
    _ContractCache := TContractCache.Create;
  Result := _ContractCache;
end;

{------------------------ 5 calls per sec/IP throttler ------------------------}

type
  IEtherscan = interface
    procedure Get(
      chain       : TChain;
      const apiKey: string;
      const query : string;
      callback    : TProc<TJsonObject, IError>);
  end;

type
  TEtherscan = class(TGetter, IEtherscan)
  public
    procedure Get(
      chain       : TChain;
      const apiKey: string;
      const query : string;
      callback    : TProc<TJsonObject, IError>);
  end;

procedure TEtherscan.Get(
  chain       : TChain;
  const apiKey: string;
  const query : string;
  callback    : TProc<TJsonObject, IError>);
begin
  const URL = endpoint(chain, TNetEncoding.URL.Encode(apiKey));
  if URL.IsErr then
    callback(nil, URL.Error)
  else
    inherited Get(TGet.Create(URL.Value + query, [], callback));
end;

var
  _Etherscan: IEtherscan = nil;

function Etherscan: IEtherscan;
const
  REQUESTS_PER_SECOND = 5;
begin
  if not Assigned(_Etherscan) then
    _Etherscan := TEtherscan.Create(REQUESTS_PER_SECOND);
  Result := _Etherscan;
end;

{------------------------------ global functions ------------------------------}

procedure getBlockNumberByTimestamp(
  client   : IWeb3;
  timestamp: TUnixDateTime;
  callback : TProc<BigInteger, IError>);
begin
  getBlockNumberByTimestamp(
    client.Chain,
    timestamp,
    client.ETHERSCAN_API_KEY,
    callback);
end;

procedure getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TProc<BigInteger, IError>);
begin
  Etherscan.Get(chain, apiKey,
    Format('&module=block&action=getblocknobytime&timestamp=%d&closest=before', [timestamp]),
  procedure(response: TJsonObject; err: IError)
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

procedure getErc20TransferEvents(
  client  : IWeb3;
  address : TAddress;
  callback: TProc<IDeserializedArray<IErc20TransferEvent>, IError>);
begin
  getErc20TransferEvents(
    client.Chain,
    address,
    client.ETHERSCAN_API_KEY,
    callback);
end;

procedure getErc20TransferEvents(
  chain       : TChain;
  address     : TAddress;
  const apiKey: string;
  callback    : TProc<IDeserializedArray<IErc20TransferEvent>, IError>);
begin
  Etherscan.Get(chain, apiKey,
    Format('&module=account&action=tokentx&address=%s&sort=desc', [address]),
  procedure(response: TJsonObject; err: IError)
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

procedure getContractABI(
  client  : IWeb3;
  contract: TAddress;
  callback: TProc<IContractABI, IError>);
begin
  getContractABI(
    client.Chain,
    contract,
    client.ETHERSCAN_API_KEY,
    callback);
end;

procedure getContractABI(
  chain       : TChain;
  contract    : TAddress;
  const apiKey: string;
  callback    : TProc<IContractABI, IError>);
begin
  ContractCache.Enter;
  try
    const I = ContractCache.IndexOf(chain, contract);
    if I > -1 then
    begin
      callback(ContractCache.Get(I), nil);
      EXIT;
    end;
  finally
    ContractCache.Leave;
  end;
  Etherscan.Get(chain, apiKey,
    Format('&module=contract&action=getabi&address=%s', [contract]),
  procedure(response: TJsonObject; err: IError)
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
      const abi = TContractABI.Create(chain, contract, &result as TJsonArray);
      ContractCache.Enter;
      try
        ContractCache.Add(abi);
      finally
        ContractCache.Leave;
      end;
      callback(abi, nil);
    finally
      &result.Free;
    end;
  end);
end;

end.
