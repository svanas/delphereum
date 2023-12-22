unit web3.eth.tenderly;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.simulate;

procedure simulate(
  const accountId,
        projectId,
        accessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const input    : string;
  const callback : TProc<IAssetChanges, IError>);

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

{-------------------------------- TAssetChange --------------------------------}

type
  TAssetChange = class(TDeserialized, IAssetChange)
  public
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

function TAssetChange.Asset: TAssetType;
begin
  const tokenInfo = getPropAsObj(FJsonValue, 'token_info');
  if not Assigned(tokenInfo) then
    Result := TAssetType.native
  else
    Result := TAssetType.Create(getPropAsStr(tokenInfo, 'standard'));
end;

function TAssetChange.Change: TChangeType;
begin
  const &type = getPropAsStr(FJsonValue, 'type');
  if SameText(&type, 'Transfer') then
    Result := Transfer
  else if SameText(&type, 'Mint') then
    Result := Mint
  else
    Result := Approve;
end;

function TAssetChange.From: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from', string(TAddress.Zero)));
end;

function TAssetChange.&To: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'to'));
end;

function TAssetChange.Amount: BigInteger;
begin
  Result := getPropAsBigInt(FJsonValue, 'raw_amount');
end;

function TAssetChange.Contract: TAddress;
begin
  const tokenInfo = getPropAsObj(FJsonValue, 'token_info');
  if not Assigned(tokenInfo) then
    Result := TAddress.Zero
  else
    Result := TAddress.Create(getPropAsStr(tokenInfo, 'contract_address'));
end;

function TAssetChange.Name: IResult<string>;
begin
  const tokenInfo = getPropAsObj(FJsonValue, 'token_info');
  if not Assigned(tokenInfo) then
    Result := TResult<string>.Err('', 'token_info is null')
  else
    Result := TResult<string>.Ok(getPropAsStr(tokenInfo, 'name'));
end;

function TAssetChange.Symbol: IResult<string>;
begin
  const tokenInfo = getPropAsObj(FJsonValue, 'token_info');
  if not Assigned(tokenInfo) then
    Result := TResult<string>.Err('', 'token_info is null')
  else
    Result := TResult<string>.Ok(getPropAsStr(tokenInfo, 'symbol'));
end;

function TAssetChange.Decimals: IResult<Integer>;
begin
  const tokenInfo = getPropAsObj(FJsonValue, 'token_info');
  if not Assigned(tokenInfo) then
    Result := TResult<Integer>.Err(0, 'token_info is null')
  else
    Result := TResult<Integer>.Ok(getPropAsInt(tokenInfo, 'decimals'));
end;

function TAssetChange.Logo: IResult<TURL>;
begin
  const tokenInfo = getPropAsObj(FJsonValue, 'token_info');
  if not Assigned(tokenInfo) then
    Result := TResult<string>.Err('', 'token_info is null')
  else
    Result := TResult<string>.Ok(getPropAsStr(tokenInfo, 'logo'));
end;

{------------------------------- TAssetChanges --------------------------------}

type
  TAssetChanges = class(TDeserializedArray<IAssetChange>, IAssetChanges)
  public
    function Item(const Index: Integer): IAssetChange; override;
    function IndexOf(const contract: TAddress): Integer;
    function Incoming(const address: TAddress): IAssetChanges;
    function Outgoing(const address: TAddress): IAssetChanges;
  end;

function TAssetChanges.Item(const Index: Integer): IAssetChange;
begin
  Result := TAssetChange.Create(TJsonArray(FJsonValue)[Index]);
end;

function TAssetChanges.IndexOf(const contract: TAddress): Integer;
begin
  const count = Self.Count;
  if count > 0 then
    for Result := 0 to Pred(count) do
      if Self.Item(Result).Contract.SameAs(contract) then
        EXIT;
  Result := -1;
end;

function TAssetChanges.Incoming(const address: TAddress): IAssetChanges;
begin
  var value := Self.FJsonValue.Clone as TJsonArray;
  try
    var index := 0;
    while index < value.Count do
    begin
      const change: IAssetChange = TAssetChange.Create(value[index]);
      if (change.Change in [Mint, Transfer]) and change.&To.SameAs(address) then
        Inc(index)
      else
        value.Remove(index);
    end;
    Result := TAssetChanges.Create(value);
  finally
    value.Free;
  end;
end;

function TAssetChanges.Outgoing(const address: TAddress): IAssetChanges;
begin
  var value := Self.FJsonValue.Clone as TJsonArray;
  try
    var index := 0;
    while index < value.Count do
    begin
      const change: IAssetChange = TAssetChange.Create(value[index]);
      if (change.Change = Transfer) and change.From.SameAs(address) then
        Inc(index)
      else
        value.Remove(index);
    end;
    Result := TAssetChanges.Create(value);
  finally
    value.Free;
  end;
end;

{---------------------------------- globals -----------------------------------}

procedure simulate(
  const accountId,
        projectId,
        accessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const input    : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  web3.http.post(
    Format('https://api.tenderly.co/api/v1/account/%s/project/%s/simulate', [accountId, projectId]),
    Format('{"network_id": %d, "from": "%s", "to": "%s", "value": %s, "input": "%s"}', [chain.Id, from, &to, value.ToString(10), input]),
    [TNetHeader.Create('X-Access-Key', accessKey), TNetHeader.Create('Content-Type', 'application/json')],
    procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      const transaction = web3.json.getPropAsObj(response, 'transaction');
      if not Assigned(transaction) then
      begin
        callback(nil, TError.Create('transaction is null'));
        EXIT;
      end;
      const info = web3.json.getPropAsObj(transaction, 'transaction_info');
      if not Assigned(info) then
      begin
        callback(nil, TError.Create('transaction.transaction_info is null'));
        EXIT;
      end;
      const trace = web3.json.getPropAsObj(info, 'call_trace');
      if not Assigned(trace) then
      begin
        callback(nil, TError.Create('transaction.transaction_info.call_trace is null'));
        EXIT;
      end;
      const changes = web3.json.getPropAsArr(trace, 'asset_changes');
      if not Assigned(changes) then
      begin
        callback(nil, TError.Create('transaction.transaction_info.call_trace.asset_changes is null'));
        EXIT;
      end;
      callback(TAssetChanges.Create(changes), nil);
    end);
end;

end.
