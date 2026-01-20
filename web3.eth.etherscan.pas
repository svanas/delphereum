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
  System.JSON, System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3, web3.eth.types, web3.json;

type
  TExplorer = (beEtherscan, beRoutescan);

  IEtherscanError = interface(IError)
  ['{4AAD53A6-FBD8-4FAB-83F7-6FDE0524CE5C}']
    function Status: Integer;
  end;

  ITransactions = interface(IDeserializedArray<ITransaction>)
    procedure FilterBy(const recipient: TAddress);
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
    function SymbolType: TSymbolType;
    function Inputs: TJsonArray;
    function Outputs: TJsonArray;
    function StateMutability: TStateMutability;
  end;

  IContractABI = interface(IDeserializedArray<IContractSymbol>)
    function Contract: TAddress;
    function IsERC20: Boolean;
    function IsERC4626: Boolean;
    function IndexOf(
      const Name      : string;
      const SymbolType: TSymbolType;
      const InputCount: Integer): Integer; overload;
    function IndexOf(
      const Name           : string;
      const SymbolType     : TSymbolType;
      const StateMutability: TStateMutability): Integer; overload;
    function IndexOf(
      const Name           : string;
      const SymbolType     : TSymbolType;
      const InputCount     : Integer;
      const StateMutability: TStateMutability): Integer; overload;
  end;

  TEtherscan = record
  private
    FChain: TChain;
    FEtherscanApiKey: string;
    FRoutescanApiKey: string;
    function apiKey(const explorer: TExplorer): string;
    function endpoint(const explorer: TExplorer): string;
  public
    constructor Create(const chain: TChain; const apiKey: string); overload;
    constructor Create(const chain: TChain; const etherscanApiKey, routescanApiKey: string); overload;
  end;

procedure getBlockNumberByTimestamp(
  const etherscan: TEtherscan;
  const timestamp: TUnixDateTime;
  const callback : TProc<BigInteger, IError>);

procedure getTransactions(
  const etherscan: TEtherscan;
  const address  : TAddress;
  const callback : TProc<ITransactions, IError>);

procedure getLatestTransaction(
  const etherscan: TEtherscan;
  const address  : TAddress;
  const callback : TProc<ITransaction, IError>);

procedure getErc20TransferEvents(
  const etherscan: TEtherscan;
  const address  : TAddress;
  const callback : TProc<IDeserializedArray<IErc20TransferEvent>, IError>);

procedure getContractABI(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<IContractABI, IError>);

procedure getContractSourceCode(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<string, IError>);

procedure contractIsProxy(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<Boolean, IError>);

procedure getFundedBy(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<TAddress, IError>);

implementation

uses
  // Delphi
  System.Classes, System.Generics.Collections, System.NetEncoding, System.TypInfo,
  // web3
  web3.eth.tx, web3.http;

{--------------------------------- TEtherscan ---------------------------------}

constructor TEtherscan.Create(const chain: TChain; const apiKey: string);
begin
  Create(chain, apiKey, 'placeholder');
end;

constructor TEtherscan.Create(const chain: TChain; const etherscanApiKey, routescanApiKey: string);
begin
  FChain := chain;
  FEtherscanApiKey := etherscanApiKey;
  FRoutescanApiKey := routescanApiKey;
end;

function TEtherscan.apiKey(const explorer: TExplorer): string;
begin
  if explorer = beRoutescan then Result := FRoutescanApiKey else Result := FEtherscanApiKey;
end;

function TEtherscan.endpoint(const explorer: TExplorer): string;
begin
  if explorer = beRoutescan then
    Result := Format('https://api.routescan.io/v2/network/mainnet/evm/%d/etherscan/api?', [FChain.Id])
  else
    Result := Format('https://api.etherscan.io/v2/api?chainid=%d&', [FChain.Id]);
  if apiKey(explorer) <> '' then
    Result := Result + Format('apikey=%s&', [TNetEncoding.URL.Encode(apiKey(explorer))]);
end;

{------------------------------ TEtherscanError -------------------------------}

type
  TEtherscanError = class(TError, IEtherscanError)
  private
    FStatus: Integer;
  public
    constructor Create(const aStatus: Integer; const aBody: TJsonValue);
    function Status: Integer;
  end;

constructor TEtherscanError.Create(const aStatus: Integer; const aBody: TJsonValue);

  function msg: string;
  begin
    Result := 'an unknown error occurred';
    if Assigned(aBody) then
    begin
      Result := web3.json.getPropAsStr(aBody, 'message', Result);
      if Result = 'NOTOK' then
        Result := web3.json.getPropAsStr(aBody, 'result', Result);
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

{------------------------------- TTransactions --------------------------------}

type
  TTransactions = class(TDeserializedArray<ITransaction>, ITransactions)
  public
    function Item(const Index: Integer): ITransaction; override;
    procedure FilterBy(const recipient: TAddress);
  end;

function TTransactions.Item(const Index: Integer): ITransaction;
begin
  Result := createTransaction(TJsonArray(FJsonValue)[Index]);
end;

procedure TTransactions.FilterBy(const recipient: TAddress);
begin
  var I := 0;
  while I < Self.Count do
    if Self.Item(I).&To.SameAs(recipient) then
      Inc(I)
    else
      Self.Delete(I);
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
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from', string(TAddress.Zero)));
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
    function SymbolType: TSymbolType;
    function Inputs: TJsonArray;
    function Outputs: TJsonArray;
    function StateMutability: TStateMutability;
  end;

function TContractSymbol.Name: string;
begin
  Result := getPropAsStr(FJsonValue, 'name');
end;

function TContractSymbol.SymbolType: TSymbolType;
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
    function IsERC20: Boolean;
    function IsERC4626: Boolean;
    function IndexOf(
      const Name      : string;
      const SymbolType: TSymbolType;
      const InputCount: Integer): Integer; overload;
    function IndexOf(
      const Name           : string;
      const SymbolType     : TSymbolType;
      const StateMutability: TStateMutability): Integer; overload;
    function IndexOf(
      const Name           : string;
      const SymbolType     : TSymbolType;
      const InputCount     : Integer;
      const StateMutability: TStateMutability): Integer; overload;
    constructor Create(const aChain: TChain; const aContract: TAddress; const aJsonArray: TJsonArray); reintroduce;
  end;

constructor TContractABI.Create(const aChain: TChain; const aContract: TAddress; const aJsonArray: TJsonArray);
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

function TContractABI.IsERC20: Boolean;
begin
  Result :=
    (Self.IndexOf('name', TSymbolType.Function, 0, TStateMutability.View) > -1)
  and
    (Self.IndexOf('symbol', TSymbolType.Function, 0, TStateMutability.View) > -1)
  and
    (Self.IndexOf('decimals', TSymbolType.Function, 0, TStateMutability.View) > -1)
  and
    (Self.IndexOf('balanceOf', TSymbolType.Function, 1, TStateMutability.View) > -1)
  and
    (Self.IndexOf('totalSupply', TSymbolType.Function, 0, TStateMutability.View) > -1)
  and
    (Self.IndexOf('transfer', TSymbolType.Function, 2, TStateMutability.NonPayable) > -1);
end;

function TContractABI.IsERC4626: Boolean;
begin
  Result :=
    (Self.IndexOf('deposit', TSymbolType.Function, 2, TStateMutability.NonPayable) > -1)
  and
    (Self.IndexOf('withdraw', TSymbolType.Function, 3, TStateMutability.NonPayable) > -1);
end;

function TContractABI.IndexOf(
  const Name      : string;
  const SymbolType: TSymbolType;
  const InputCount: Integer): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
    begin
      const Item = Self.Item(Result);
      if  (Item.Name = Name)
      and (Item.SymbolType = SymbolType)
      and (Item.Inputs.Count = InputCount) then
        EXIT;
    end;
  Result := -1;
end;

function TContractABI.IndexOf(
  const Name           : string;
  const SymbolType     : TSymbolType;
  const StateMutability: TStateMutability): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
    begin
      const Item = Self.Item(Result);
      if  (Item.Name = Name)
      and (Item.SymbolType = SymbolType)
      and (Item.StateMutability = StateMutability) then
        EXIT;
    end;
  Result := -1;
end;

function TContractABI.IndexOf(
  const Name           : string;
  const SymbolType     : TSymbolType;
  const InputCount     : Integer;
  const StateMutability: TStateMutability): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
    begin
      const Item = Self.Item(Result);
      if  (Item.Name = Name)
      and (Item.SymbolType = SymbolType)
      and (Item.Inputs.Count = InputCount)
      and (Item.StateMutability = StateMutability) then
        EXIT;
    end;
  Result := -1;
end;

{---------------------------- HTTP helper functions ---------------------------}

procedure get(
  const explorer : TExplorer;                 // Etherscan or Routescan
  const etherscan: TEtherscan;                // chain and API key
  const query    : string;                    // endpoint, for example "module=account&" or "module=contract&"
  const callback : TProc<TJsonValue, IError>; // callback with HTTP response (or HTTP error)
  const backoff  : Integer;                   // time to wait (in milliseconds) before retry (if a rate limit error comes back)
  const remember : TJsonValue); overload;     // a previous HTTP response to keep and return (if nothing else worked)
begin
  web3.http.get(etherscan.endpoint(explorer) + query, [], procedure(response: TJsonValue; err: IError)
  begin
    {"status":"0", "message":"NOTOK", "result":"Max rate limit reached, please use API Key for higher rate limit"}
    if  (backoff <= web3.http.MAX_BACKOFF_SECONDS * 1000)
    and (response <> nil) and (web3.json.getPropAsInt(response, 'status') = 0)
    and web3.json.getPropAsStr(response, 'result').Contains('rate limit') then
    begin
      TThread.Sleep(backoff);
      get(explorer, etherscan, query, callback, backoff * 2, remember);
      EXIT;
    end
    else
      {"status":"0", "message":"NOTOK", "result":"blah blah blah"}
      if (explorer = beEtherscan) and (Assigned(err) or (Assigned(response) and (web3.json.getPropAsInt(response, 'status') = 0))) then
      begin
        if Assigned(response) then
  		  get(beRoutescan, etherscan, query, callback, 250, response.Clone as TJsonValue)
		else
		  get(beRoutescan, etherscan, query, callback, 250, remember);
        EXIT;
      end;
    // return the Etherscan (not the Routescan) response (if we have any and the Routescan response is in error)
    if Assigned(remember) then
    try
      if Assigned(err) or (Assigned(response) and (web3.json.getPropAsInt(response, 'status') = 0)) then
      begin
        callback(remember, nil);
        EXIT;
      end;
    finally
      remember.Free;
    end;
    // otherwise return this response
    callback(response, err);
  end);
end;

procedure get(const etherscan: TEtherscan; const query: string; const callback : TProc<TJsonValue, IError>); overload;
begin
  get(beEtherscan, etherscan, query, callback, 250, nil);
end;

{------------------------------ global functions ------------------------------}

procedure getBlockNumberByTimestamp(
  const etherscan: TEtherscan;
  const timestamp: TUnixDateTime;
  const callback : TProc<BigInteger, IError>);
begin
  get(etherscan, Format('module=block&action=getblocknobytime&timestamp=%d&closest=before', [timestamp]),
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

procedure getTransactions(
  const etherscan: TEtherscan;
  const address  : TAddress;
  const callback : TProc<ITransactions, IError>);
begin
  get(etherscan, Format('module=account&action=txlist&address=%s&sort=desc', [address]),
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
      callback(nil, TEtherscanError.Create(status, response));
      EXIT;
    end;
    callback(TTransactions.Create(&array), nil);
  end);
end;

procedure getLatestTransaction(
  const etherscan: TEtherscan;
  const address  : TAddress;
  const callback : TProc<ITransaction, IError>);
begin
  get(etherscan, Format('module=account&action=txlist&address=%s&sort=desc&page=1&offset=1', [address]),
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
      callback(nil, TEtherscanError.Create(status, response));
      EXIT;
    end;
    if &array.Count = 0 then
    begin
      callback(nil, nil);
      EXIT;
    end;
    callback(createTransaction(&array.Items[0]), nil);
  end);
end;

procedure getErc20TransferEvents(
  const etherscan: TEtherscan;
  const address  : TAddress;
  const callback : TProc<IDeserializedArray<IErc20TransferEvent>, IError>);
begin
  get(etherscan, Format('module=account&action=tokentx&address=%s&sort=desc', [address]),
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
      callback(nil, TEtherscanError.Create(status, response));
      EXIT;
    end;
    callback(TErc20TransferEvents.Create(&array), nil);
  end);
end;

procedure getContractABI(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<IContractABI, IError>);
begin
  get(etherscan, Format('module=contract&action=getabi&address=%s', [contract]),
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
      callback(nil, TEtherscanError.Create(status, response));
      EXIT;
    end;
    try
      callback(TContractABI.Create(etherscan.FChain, contract, &result as TJsonArray), nil);
    finally
      &result.Free;
    end;
  end);
end;

procedure getContractSourceCode(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<string, IError>);
begin
  get(etherscan, Format('module=contract&action=getsourcecode&address=%s', [contract]),
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
      callback('', TEtherscanError.Create(status, response));
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
      callback('', TEtherscanError.Create(status, response));
    finally
      &result.Free;
    end;
  end);
end;

procedure contractIsProxy(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<Boolean, IError>);
begin
  get(etherscan, Format('module=contract&action=getsourcecode&address=%s', [contract]),
  procedure(response: TJsonValue; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(False, err);
      EXIT;
    end;
    const status = web3.json.getPropAsInt(response, 'status');
    if status = 0 then
    begin
      callback(False, TEtherscanError.Create(status, response));
      EXIT;
    end;
    const &result = unmarshal(web3.json.getPropAsStr(response, 'result'));
    if not Assigned(&result) then
    begin
      callback(False, TEtherscanError.Create(status, response));
      EXIT;
    end;
    try
      if &result is TJsonArray then
      begin
        const &array = TJsonArray(&result);
        if &array.Count > 0 then
        begin
          callback(StrToIntDef(web3.json.getPropAsStr(&array[0], 'Proxy'), 0) <> 0, nil);
          EXIT;
        end;
      end;
      callback(False, TEtherscanError.Create(status, response));
    finally
      &result.Free;
    end;
  end);
end;

procedure getFundedBy(
  const etherscan: TEtherscan;
  const contract : TAddress;
  const callback : TProc<TAddress, IError>);
begin
  get(etherscan, Format('module=account&action=fundedby&address=%s', [contract]), procedure(response: TJsonValue; err: IError)
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
      callback('', TEtherscanError.Create(status, response));
      EXIT;
    end;
    try
      callback(TAddress.Create(web3.json.getPropAsStr(&result, 'fundingAddress')), nil);
    finally
      &result.Free;
    end;
  end);
end;

end.
