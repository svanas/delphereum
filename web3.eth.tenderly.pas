unit web3.eth.tenderly;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth.simulate;

// simulate transaction, return array of asset changes
procedure simulate(
  const accountId,
        projectId,
        accessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const input    : string;
  const callback : TProc<IAssetChanges, IError>);

// simulate transaction, return incoming assets that are honeypots (eg. you cannot sell)
procedure honeypots(
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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3.eth.abi,
  web3.eth.types,
  web3.http,
  web3.json,
  web3.utils;

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
    Result := TAddress.Create(getPropAsStr(tokenInfo, 'contract_address', string(TAddress.Zero)));
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
  TAssetChanges = class(TCustomAssetChanges)
  strict protected
    class function CreateAssetChange(const aJsonObject: TJsonValue): IAssetChange; override;
    class function CreateAssetChanges(const aJsonArray: TJsonArray): IAssetChanges; override;
  end;

class function TAssetChanges.CreateAssetChange(const aJsonObject: TJsonValue): IAssetChange;
begin
  Result := TAssetChange.Create(aJsonObject);
end;

class function TAssetChanges.CreateAssetChanges(const aJsonArray: TJsonArray): IAssetChanges;
begin
  Result := TAssetChanges.Create(aJsonArray);
end;

{------------------------------ TRawTransaction -------------------------------}

type
  TRawTransaction = class(TCustomRawTransaction)
  public
    function Marshal: string; override;
  end;

function TRawTransaction.Marshal: string;
begin
  Result := Format('{"network_id": %d, "from": "%s", "to": "%s", "value": %s, "input": "%s"}',
            [Self.FChain.Id, Self.FFrom, Self.FTo, Self.FValue.ToString(10), Self.FData]);
end;

{---------------------------------- globals -----------------------------------}

function getAssetChanges(const aJsonObject: TJsonValue): IResult<TJsonArray>;
begin
  const transaction = web3.json.getPropAsObj(aJsonObject, 'transaction');
  if not Assigned(transaction) then
  begin
    Result := TResult<TJsonArray>.Err(nil, 'transaction is null');
    EXIT;
  end;
  const info = web3.json.getPropAsObj(transaction, 'transaction_info');
  if not Assigned(info) then
  begin
    Result := TResult<TJsonArray>.Err(nil, 'transaction.transaction_info is null');
    EXIT;
  end;
  const changes = web3.json.getPropAsArr(info, 'asset_changes');
  if not Assigned(changes) then
    Result := TResult<TJsonArray>.Ok(nil)
  else
    Result := TResult<TJsonArray>.Ok(changes);
end;

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
        callback(nil, err)
      else
        getAssetChanges(response)
          .ifErr(procedure(err: IError)
          begin
            callback(nil, err);
          end)
          .&else(procedure(changes: TJsonArray)
          begin
            callback(TAssetChanges.Create(changes), nil);
          end);
    end);
end;

procedure simulateBundle(
  const accountId,
        projectId,
        accessKey: string;
  const tx1, tx2 : IRawTransaction;
  const callback : TProc<TJsonArray, IError>);
begin
  web3.http.post(
    Format('https://api.tenderly.co/api/v1/account/%s/project/%s/simulate-bundle', [accountId, projectId]),
    Format('{"simulations": [%s, %s]}', [tx1.Marshal, tx2.Marshal]),
    [TNetHeader.Create('X-Access-Key', accessKey), TNetHeader.Create('Content-Type', 'application/json')],
    procedure(response: TJsonValue; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      const results = web3.json.getPropAsArr(response, 'simulation_results');
      if not Assigned(results) then
      begin
        callback(nil, TError.Create('simulation_results is null'));
        EXIT;
      end;
      callback(results, err);
    end);
end;

procedure honeypots(
  const accountId,
        projectId,
        accessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const input    : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  // step #1: simulate asset changes
  simulate(accountId, projectId, accessKey, chain, from, &to, value, input, procedure(changes1: IAssetChanges; err: IError)
  begin
    if Assigned(err) or not Assigned(changes1) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // step #2: get incoming tokens
    const incoming = changes1.Incoming(from);
    // step #3: simulate a sell for each and every incoming erc20
    var next: TProc<Integer, TProc>;
    next := procedure(incomingIndex: Integer; done: TProc)
    begin
      if (incoming = nil) or (incomingIndex >= incoming.Count) then
      begin
        done;
        EXIT;
      end;
      const change = incoming.Item(incomingIndex);
      if change.Asset <> erc20 then
      begin
        incoming.Delete(incomingIndex);
        next(incomingIndex, done);
        EXIT;
      end;
      simulateBundle(accountId, projectId, accessKey,
        TRawTransaction.Create(chain, from, &to, value, input),
        TRawTransaction.Create(
          chain,
          from,
          change.Contract,
          0,
          web3.eth.abi.encode('transfer(address,uint256)', ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045', web3.utils.toHex(change.Amount)])
        ),
        procedure(response: TJsonArray; err: IError)
        begin
          if (err <> nil) or (response = nil) or (response.Count < 2) then
          begin
            callback(nil, err);
            EXIT;
          end;
          getAssetChanges(response[1])
            .ifErr(procedure(err: IError)
            begin
              callback(nil, err);
            end)
            .&else(procedure(changes2: TJsonArray)
            begin
              const outgoing = TAssetChanges.Create(changes2).Outgoing(from);
              if Assigned(outgoing) then
              begin
                const outgoingIndex = outgoing.IndexOf(change.Contract);
                if (outgoingIndex > -1) and (outgoing.Item(outgoingIndex).Amount = change.Amount) then
                begin
                  incoming.Delete(incomingIndex);
                  next(incomingIndex, done);
                  EXIT;
                end;
              end;
              next(incomingIndex + 1, done);
            end);
        end);
    end;
    next(0, procedure
    begin
      callback(incoming, nil);
    end);
  end)
end;

end.
