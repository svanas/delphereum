unit web3.eth.simulate;

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
  TChangeType = (Approve, Mint, Transfer);

  IAssetChange = interface
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

  IAssetChanges = interface(IDeserializedArray<IAssetChange>)
    function IndexOf(const contract: TAddress): Integer;
    function Incoming(const address: TAddress): IAssetChanges;
    function Outgoing(const address: TAddress): IAssetChanges;
  end;

  TCustomAssetChanges = class abstract(TDeserializedArray<IAssetChange>, IAssetChanges)
  strict protected
    class function CreateAssetChange(const aJsonObject: TJsonValue): IAssetChange; virtual; abstract;
    class function CreateAssetChanges(const aJsonArray: TJsonArray): IAssetChanges; virtual; abstract;
  public
    function Item(const Index: Integer): IAssetChange; override;
    function IndexOf(const contract: TAddress): Integer;
    function Incoming(const address: TAddress): IAssetChanges;
    function Outgoing(const address: TAddress): IAssetChanges;
  end;

  IRawTransaction = interface
    function Marshal: string;
  end;

  TCustomRawTransaction = class abstract(TInterfacedObject, IRawTransaction)
  strict protected
    FChain: TChain;
    FFrom : TAddress;
    FTo   : TAddress;
    FValue: TWei;
    FData : string;
  public
    function Marshal: string; virtual; abstract;
    constructor Create(const chain: TChain; const from, &to: TAddress; const value: TWei; const data: string);
  end;

// simulate transaction, return array of asset changes
procedure simulate(
  const alchemyApiKey,
        tenderlyAccountId,
        tenderlyProjectId,
        tenderlyaccessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);

// simulate transaction, return incoming assets that are honeypots (eg. you cannot sell)
procedure honeypots(
  const alchemyApiKey,
        tenderlyaccountId,
        tenderlyprojectId,
        tenderlyaccessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);

implementation

uses
  // Delphi
  System.Generics.Collections,
  // web3
  web3.eth.alchemy.api,
  web3.eth.tenderly,
  web3.eth.types;

{---------------------------- TCustomAssetChanges -----------------------------}

function TCustomAssetChanges.Item(const Index: Integer): IAssetChange;
begin
  Result := Self.CreateAssetChange(TJsonArray(FJsonValue)[Index]);
end;

function TCustomAssetChanges.IndexOf(const contract: TAddress): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
      if Self.Item(Result).Contract.SameAs(contract) then
        EXIT;
  Result := -1;
end;

function TCustomAssetChanges.Incoming(const address: TAddress): IAssetChanges;
begin
  Result := nil;
  if not Assigned(Self.FJsonValue) then
    EXIT;
  var value := Self.FJsonValue.Clone as TJsonArray;
  try
    var index := 0;
    while index < value.Count do
    begin
      const change: IAssetChange = Self.CreateAssetChange(value[index]);
      if (change.Change in [Mint, Transfer]) and change.&To.SameAs(address) then
        Inc(index)
      else
        value.Remove(index);
    end;
    Result := Self.CreateAssetChanges(value);
  finally
    value.Free;
  end;
end;

function TCustomAssetChanges.Outgoing(const address: TAddress): IAssetChanges;
begin
  Result := nil;
  if not Assigned(Self.FJsonValue) then
    EXIT;
  var value := Self.FJsonValue.Clone as TJsonArray;
  try
    var index := 0;
    while index < value.Count do
    begin
      const change: IAssetChange = Self.CreateAssetChange(value[index]);
      if (change.Change in [Mint, Transfer]) and change.From.SameAs(address) then
        Inc(index)
      else
        value.Remove(index);
    end;
    Result := Self.CreateAssetChanges(value);
  finally
    value.Free;
  end;
end;

{--------------------------- TCustomRawTransaction ----------------------------}

constructor TCustomRawTransaction.Create(const chain: TChain; const from, &to: TAddress; const value: BigInteger; const data: string);
begin
  Self.FChain := chain;
  Self.FFrom  := from;
  Self.FTo    := &to;
  Self.FValue := value;
  Self.FData  := data;
end;

{---------------------------------- globals -----------------------------------}

procedure simulate(
  const alchemyApiKey,
        tenderlyAccountId,
        tenderlyProjectId,
        tenderlyaccessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  web3.eth.alchemy.api.simulate(alchemyApiKey, chain, from, &to, value, data, procedure(changes: IAssetChanges; err: IError)
  begin
    if not Assigned(err) then
      callback(changes, err)
    else
      web3.eth.tenderly.simulate(tenderlyAccountId, tenderlyProjectId, tenderlyAccessKey, chain, from, &to, value, data, callback);
  end);
end;

procedure honeypots(
  const alchemyApiKey,
        tenderlyaccountId,
        tenderlyprojectId,
        tenderlyaccessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  web3.eth.alchemy.api.honeypots(alchemyApiKey, chain, from, &to, value, data, procedure(honeypots: IAssetChanges; err: IError)
  begin
    if not Assigned(err) then
      callback(honeypots, err)
    else
      web3.eth.tenderly.honeypots(tenderlyAccountId, tenderlyProjectId, tenderlyAccessKey, chain, from, &to, value, data, callback);
  end)
end;

end.
