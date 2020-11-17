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
  System.Types,
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
    constructor Create(aStatus: Integer; const aMsg: string);
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
    function Count: Integer;
    function Item(const Index: Integer): IContractSymbol;
  end;

  TAsyncContractABI = reference to procedure(abi: IContractABI; err: IError);

function getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TAsyncQuantity): IAsyncResult;

function getErc20TransferEvents(
  chain       : TChain;
  address     : TAddress;
  const apiKey: string;
  callback    : TAsyncErc20TransferEvents): IAsyncResult;

// https://github.com/trufflesuite/truffle-contract-schema/blob/develop/spec/abi.spec.json
function getContractABI(
  chain       : TChain;
  contract    : TAddress;
  const apiKey: string;
  callback    : TAsyncContractABI): IAsyncResult;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.NetEncoding,
  System.SysUtils,
  System.TypInfo,
  // web3
  web3.http,
  web3.json;

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

{ TEtherscanError }

constructor TEtherscanError.Create(aStatus: Integer; const aMsg: string);
begin
  inherited Create(aMsg);
  FStatus := aStatus;
end;

function TEtherscanError.Status: Integer;
begin
  Result := FStatus;
end;

{ TErc20TransferEvent }

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

{ TErc20TransferEvents }

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

{ TContractSymbol }

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

{ TContractABI }

type
  TContractABI = class(TInterfacedObject, IContractABI)
  private
    FJsonArray: TJsonArray;
  public
    function Count: Integer;
    function Item(const Index: Integer): IContractSymbol;
    constructor Create(aJsonArray: TJsonArray);
    destructor Destroy; override;
  end;

constructor TContractABI.Create(aJsonArray: TJsonArray);
begin
  inherited Create;
  FJsonArray := aJsonArray;
end;

destructor TContractABI.Destroy;
begin
  if Assigned(FJsonArray) then
    FJsonArray.Free;
  inherited Destroy;
end;

function TContractABI.Count: Integer;
begin
  Result := FJsonArray.Count;
end;

function TContractABI.Item(const Index: Integer): IContractSymbol;
begin
  Result := TContractSymbol.Create(FJsonArray.Items[Index].Clone as TJsonObject);
end;

{ global functions }

function getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TAsyncQuantity): IAsyncResult;
begin
  Result := web3.http.get(
    endpoint(chain, TNetEncoding.URL.Encode(apiKey)) +
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
      callback(0, TEtherscanError.Create(status, web3.json.getPropAsStr(resp, 'message')))
    else
      callback(web3.json.getPropAsBig(resp, 'result', 0), nil);
  end);
end;

function getErc20TransferEvents(
  chain       : TChain;
  address     : TAddress;
  const apiKey: string;
  callback    : TAsyncErc20TransferEvents): IAsyncResult;
begin
  Result := web3.http.get(
    endpoint(chain, TNetEncoding.URL.Encode(apiKey)) +
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
      callback(nil, TEtherscanError.Create(status, web3.json.getPropAsStr(resp, 'message')));
      EXIT;
    end;
    &array := web3.json.getPropAsArr(resp, 'result');
    if not Assigned(&array) then
    begin
      callback(nil, TEtherscanError.Create(status, 'an unknown error occurred'));
      EXIT;
    end;
    callback(TErc20TransferEvents.Create(&array.Clone as TJsonArray), nil);
  end);
end;

function getContractABI(
  chain       : TChain;
  contract    : TAddress;
  const apiKey: string;
  callback    : TAsyncContractABI): IAsyncResult;
begin
  Result := web3.http.get(
    endpoint(chain, TNetEncoding.URL.Encode(apiKey)) +
    Format('&module=contract&action=getabi&address=%s', [contract]),
  procedure(resp: TJsonObject; err: IError)
  var
    status : Integer;
    &result: TJsonValue;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    status := web3.json.getPropAsInt(resp, 'status');
    if status = 0 then
    begin
      callback(nil, TEtherscanError.Create(status, web3.json.getPropAsStr(resp, 'message')));
      EXIT;
    end;
    &result := unmarshal(web3.json.getPropAsStr(resp, 'result'));
    if not Assigned(&result) then
    begin
      callback(nil, TEtherscanError.Create(status, 'an unknown error occurred'));
      EXIT;
    end;
    try
      callback(TContractABI.Create(&result.Clone as TJsonArray), nil);
    finally
      &result.Free;
    end;
  end);
end;

end.
