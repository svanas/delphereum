unit web3.eth.blocknative;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.json;

type
  IBalanceChange = interface
  end;

  IBalanceChanges = interface(IDeserializedArray<IBalanceChange>)
  end;

function getNetwork(const chain: TChain): IResult<string>;

procedure simulate(
  const apiKey,
        apiSecret: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const input    : string;
  const gasLimit : BigInteger;
  const gasPrice : TWei;
  const callback : TProc<IBalanceChanges, IError>);

implementation

uses
  // Delphi
  System.JSON,
  System.Net.URLClient,
  // web3
  web3.http;

function getNetwork(const chain: TChain): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok('main')
  else if chain = Goerli then
    Result := TResult<string>.Ok('goerli')
  else if chain = BNB then
    Result := TResult<string>.Ok('bsc-main')
  else if chain = Gnosis then
    Result := TResult<string>.Ok('xdai')
  else if chain = Polygon then
    Result := TResult<string>.Ok('matic-main')
  else if chain = PolygonMumbai then
    Result := TResult<string>.Ok('matic-mumbai')
  else if chain = Fantom then
    Result := TResult<string>.Ok('fantom-main')
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

procedure simulate(
  const apiKey,
        apiSecret: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const input    : string;
  const gasLimit : BigInteger;
  const gasPrice : TWei;
  const callback : TProc<IBalanceChanges, IError>);
begin
  getNetwork(chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err);
    end)
    .&else(procedure(network: string)
    begin
      web3.http.post(
        'https://api.blocknative.com/simulate',
        Format('{"system": "ethereum", "network": %s, "transactions": [{"from": %s, "to": %s, "value": %s, "input": %s, "gas": %s, "gasPrice": %s}]}', [
          web3.json.quoteString(network, '"'),
          web3.json.quoteString(string(from), '"'),
          web3.json.quoteString(string(&to), '"'),
          value.ToString(10),
          web3.json.quoteString(input, '"'),
          gasLimit.ToString(10),
          gasPrice.ToString(10)
        ]),
        [TNetHeader.Create('credentials', Format('%s:%s', [apiKey, apiSecret])), TNetHeader.Create('Content-Type', 'application/json')],
        procedure(value: TJsonValue; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(nil, err);
            EXIT;
          end;
          const error = web3.json.getPropAsArr(value, 'error');
          if Assigned(error) and (error.Count > 0) then
          begin
            if error[0] is TJsonString then
              callback(nil, TError.Create(TJsonString(error[0]).Value))
            else
              callback(nil, TError.Create('an unknown error occurred'));
            EXIT;
          end;

        end);
    end);
end;

end.
