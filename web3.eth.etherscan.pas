{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.etherscan;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  EEtherscan = class(EWeb3);

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

  IErc20TransferEvents = interface
    function Count: Integer;
    function Item(const Index: Integer): IErc20TransferEvent;
  end;

  TAsyncErc20TransferEvents = reference to procedure(events: IErc20TransferEvents; err: IError);

  TSymbolType = (UnknownSymbol, &Function, &Constructor, Fallback, Event);

  TStateMutability = (UnknownMutability, Pure, View, NonPayable, Payable);

  IContractSymbol = interface
    function Name: string;
    function &Type: TSymbolType;
    function Inputs: TJsonArray;
    function Outputs: TJsonArray;
    function StateMutability: TStateMutability;
  end;

  IContractABI = interface
    function Chain: TChain;
    function Count: Integer;
    function Contract: TAddress;
    function Item(const Index: Integer): IContractSymbol;
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

  TAsyncContractABI = reference to procedure(abi: IContractABI; err: IError);

procedure getBlockNumberByTimestamp(
  client      : TWeb3;
  timestamp   : TUnixDateTime;
  callback    : TAsyncQuantity); overload;
procedure getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TAsyncQuantity); overload;

procedure getErc20TransferEvents(
  client      : TWeb3;
  address     : TAddress;
  callback    : TAsyncErc20TransferEvents); overload;
procedure getErc20TransferEvents(
  chain       : TChain;
  address     : TAddress;
  const apiKey: string;
  callback    : TAsyncErc20TransferEvents); overload;

procedure getContractABI(
  client      : TWeb3;
  contract    : TAddress;
  callback    : TAsyncContractABI); overload;
procedure getContractABI(
  chain       : TChain;
  contract    : TAddress;
  const apiKey: string;
  callback    : TAsyncContractABI); overload;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.NetEncoding,
  System.SysUtils,
  System.TypInfo,
  // web3
  web3.http,
  web3.json,
  web3.sync;

function endpoint(chain: TChain; const apiKey: string): string;
const
  ENDPOINT: array[TChain] of string = (
    'https://api.etherscan.io/api?apikey=%s',         // Mainnet
    'https://api-ropsten.etherscan.io/api?apikey=%s', // Ropsten
    'https://api-rinkeby.etherscan.io/api?apikey=%s', // Rinkeby
    'https://api-goerli.etherscan.io/api?apikey=%s',  // Goerli
    '',                                               // RSK_main_net
    '',                                               // RSK_test_net
    'https://api-kovan.etherscan.io/api?apikey=%s',   // Kovan
    '',                                               // xDai
    ''                                                // Ganache
  );
begin
  Result := ENDPOINT[chain];
  if Result = '' then
    raise EEtherscan.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))])
  else
    Result := Format(Result, [apiKey]);
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
  TErc20TransferEvent = class(TInterfacedObject, IErc20TransferEvent)
  private
    FJsonObject: TJsonObject;
  public
    function Hash: TTxHash;
    function From: TAddress;
    function &To: TAddress;
    function Contract: TAddress;
    function Value: BigInteger;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TErc20TransferEvent.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TErc20TransferEvent.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TErc20TransferEvent.Hash: TTxHash;
begin
  Result := TTxHash(getPropAsStr(FJsonObject, 'hash'));
end;

function TErc20TransferEvent.From: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonObject, 'from'));
end;

function TErc20TransferEvent.&To: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonObject, 'to'));
end;

function TErc20TransferEvent.Contract: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonObject, 'contractAddress'));
end;

function TErc20TransferEvent.Value: BigInteger;
begin
  Result := getPropAsBig(FJsonObject, 'value', 0);
end;

{---------------------------- TErc20TransferEvents ----------------------------}

type
  TErc20TransferEvents = class(TInterfacedObject, IErc20TransferEvents)
  private
    FJsonArray: TJsonArray;
  public
    function Count: Integer;
    function Item(const Index: Integer): IErc20TransferEvent;
    constructor Create(aJsonArray: TJsonArray);
    destructor Destroy; override;
  end;

constructor TErc20TransferEvents.Create(aJsonArray: TJsonArray);
begin
  inherited Create;
  FJsonArray := aJsonArray;
end;

destructor TErc20TransferEvents.Destroy;
begin
  if Assigned(FJsonArray) then
    FJsonArray.Free;
  inherited Destroy;
end;

function TErc20TransferEvents.Count: Integer;
begin
  Result := FJsonArray.Count;
end;

function TErc20TransferEvents.Item(const Index: Integer): IErc20TransferEvent;
begin
  Result := TErc20TransferEvent.Create(FJsonArray.Items[Index].Clone as TJsonObject);
end;

{------------------------------ TContractSymbol -------------------------------}

type
  TContractSymbol = class(TInterfacedObject, IContractSymbol)
  private
    FJsonObject: TJsonObject;
  public
    function Name: string;
    function &Type: TSymbolType;
    function Inputs: TJsonArray;
    function Outputs: TJsonArray;
    function StateMutability: TStateMutability;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TContractSymbol.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TContractSymbol.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TContractSymbol.Name: string;
begin
  Result := getPropAsStr(FJsonObject, 'name');
end;

function TContractSymbol.&Type: TSymbolType;
var
  S: string;
begin
  S := getPropAsStr(FJsonObject, 'type');
  for Result := Low(TSymbolType) to High(TSymbolType) do
    if SameText(GetEnumName(TypeInfo(TSymbolType), Integer(Result)), S) then
      EXIT;
  Result := UnknownSymbol;
end;

function TContractSymbol.Inputs: TJsonArray;
begin
  Result := getPropAsArr(FJsonObject, 'inputs');
end;

function TContractSymbol.Outputs: TJsonArray;
begin
  Result := getPropAsArr(FJsonObject, 'outputs');
end;

function TContractSymbol.StateMutability: TStateMutability;
var
  S: string;
begin
  S := getPropAsStr(FJsonObject, 'stateMutability');
  for Result := Low(TStateMutability) to High(TStateMutability) do
    if SameText(GetEnumName(TypeInfo(TStateMutability), Integer(Result)), S) then
      EXIT;
  Result := UnknownMutability;
end;

{-------------------------------- TContractABI --------------------------------}

type
  TContractABI = class(TInterfacedObject, IContractABI)
  private
    FChain: TChain;
    FContract: TAddress;
    FJsonArray: TJsonArray;
  public
    function Chain: TChain;
    function Count: Integer;
    function Contract: TAddress;
    function Item(const Index: Integer): IContractSymbol;
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
    constructor Create(aChain: TChain; aContract: TAddress; aJsonArray: TJsonArray);
    destructor Destroy; override;
  end;

constructor TContractABI.Create(aChain: TChain; aContract: TAddress; aJsonArray: TJsonArray);
begin
  inherited Create;
  FChain     := aChain;
  FContract  := aContract;
  FJsonArray := aJsonArray;
end;

destructor TContractABI.Destroy;
begin
  if Assigned(FJsonArray) then
    FJsonArray.Free;
  inherited Destroy;
end;

function TContractABI.Chain: TChain;
begin
  Result := FChain;
end;

function TContractABI.Count: Integer;
begin
  Result := FJsonArray.Count;
end;

function TContractABI.Contract: TAddress;
begin
  Result := FContract;
end;

function TContractABI.Item(const Index: Integer): IContractSymbol;
begin
  Result := TContractSymbol.Create(FJsonArray.Items[Index].Clone as TJsonObject);
end;

function TContractABI.IndexOf(
  const Name: string;
  &Type     : TSymbolType;
  InputCount: Integer): Integer;
var
  Item: IContractSymbol;
begin
  for Result := 0 to Pred(Count) do
  begin
    Item := Self.Item(Result);
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
var
  Item: IContractSymbol;
begin
  for Result := 0 to Pred(Count) do
  begin
    Item := Self.Item(Result);
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
var
  Item: IContractSymbol;
begin
  for Result := 0 to Pred(Count) do
  begin
    Item := Self.Item(Result);
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
  IContractCache = interface(ICriticalSingleton)
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

{----------------------- 5 calls per sec/IP rate limit ------------------------}

const
  REQUESTS_PER_SECOND = 5;

type
  TRequest = record
    endpoint: string;
    callback: TAsyncJsonObject;
    class function New(const aURL: string; aCallback: TAsyncJsonObject): TRequest; static;
  end;

class function TRequest.New(const aURL: string; aCallback: TAsyncJsonObject): TRequest;
begin
  Result.endpoint := aURL;
  Result.callback := aCallback;
end;

var
  _Queue: ICriticalQueue<TRequest> = nil;

function Queue: ICriticalQueue<TRequest>;
begin
  if not Assigned(_Queue) then
    _Queue := TCriticalQueue<TRequest>.Create;
  Result := _Queue;
end;

type
  TGet = reference to procedure(request: TRequest);

{------------------------------ global functions ------------------------------}

procedure get(
  chain       : TChain;
  const apiKey: string;
  const query : string;
  callback    : TAsyncJsonObject);
var
  _get: TGet;
begin
  _get := procedure(request: TRequest)
  begin
    web3.http.get(request.endpoint, procedure(resp: TJsonObject; err: IError)
    begin
      request.callback(resp, err);
      Queue.Enter;
      try
        Queue.Delete(0, 1);
        if Queue.Length > 0 then
        begin
          TThread.Sleep(Ceil(1000 / REQUESTS_PER_SECOND));
          _get(Queue.First);
        end;
      finally
        Queue.Leave;
      end;
    end);
  end;
  Queue.Enter;
  try
    Queue.Add(TRequest.New(endpoint(chain, TNetEncoding.URL.Encode(apiKey)) + query, callback));
    if Queue.Length = 1 then
      _get(Queue.First);
  finally
    Queue.Leave;
  end;
end;

procedure getBlockNumberByTimestamp(
  client   : TWeb3;
  timestamp: TUnixDateTime;
  callback : TAsyncQuantity);
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
  callback    : TAsyncQuantity);
begin
  get(chain, apiKey,
    Format('&module=block&action=getblocknobytime&timestamp=%d&closest=before', [timestamp]),
  procedure(resp: TJsonObject; err: IError)
  var
    status: Integer;
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    status := web3.json.getPropAsInt(resp, 'status');
    if status = 0 then
      callback(0, TEtherscanError.Create(status, resp))
    else
      callback(web3.json.getPropAsBig(resp, 'result', 0), nil);
  end);
end;

procedure getErc20TransferEvents(
  client  : TWeb3;
  address : TAddress;
  callback: TAsyncErc20TransferEvents);
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
  callback    : TAsyncErc20TransferEvents);
begin
  get(chain, apiKey,
    Format('&module=account&action=tokentx&address=%s&sort=desc', [address]),
  procedure(resp: TJsonObject; err: IError)
  var
    status: Integer;
    &array: TJsonArray;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    status := web3.json.getPropAsInt(resp, 'status');
    if status = 0 then
    begin
      callback(nil, TEtherscanError.Create(status, resp));
      EXIT;
    end;
    &array := web3.json.getPropAsArr(resp, 'result');
    if not Assigned(&array) then
    begin
      callback(nil, TEtherscanError.Create(status, nil));
      EXIT;
    end;
    callback(TErc20TransferEvents.Create(&array.Clone as TJsonArray), nil);
  end);
end;

procedure getContractABI(
  client  : TWeb3;
  contract: TAddress;
  callback: TAsyncContractABI);
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
  callback    : TAsyncContractABI);
var
  I: Integer;
begin
  ContractCache.Enter;
  try
    I := ContractCache.IndexOf(chain, contract);
    if I > -1 then
    begin
      callback(ContractCache.Get(I), nil);
      EXIT;
    end;
  finally
    ContractCache.Leave;
  end;
  get(chain, apiKey,
    Format('&module=contract&action=getabi&address=%s', [contract]),
  procedure(resp: TJsonObject; err: IError)
  var
    status : Integer;
    &result: TJsonValue;
    abi    : IContractABI;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    status := web3.json.getPropAsInt(resp, 'status');
    if status = 0 then
    begin
      callback(nil, TEtherscanError.Create(status, resp));
      EXIT;
    end;
    &result := unmarshal(web3.json.getPropAsStr(resp, 'result'));
    if not Assigned(&result) then
    begin
      callback(nil, TEtherscanError.Create(status, nil));
      EXIT;
    end;
    try
      abi := TContractABI.Create(chain, contract, &result.Clone as TJsonArray);
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
