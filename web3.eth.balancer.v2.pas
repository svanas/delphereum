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

unit web3.eth.balancer.v2;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.abi,
  web3.eth.contract,
  web3.eth.logs,
  web3.eth.tokenlists,
  web3.eth.types;

type
  TSwapKind = (
    GivenIn,
    GivenOut
  );

  ISingleSwap = interface end;

  TSingleSwap = class(TInterfacedObject, IContractStruct, ISingleSwap)
  private
    FPoolId  : TBytes32;
    FKind    : TSwapKind;
    FAssetIn : TAddress;
    FAssetOut: TAddress;
    FAmount  : BigInteger;
  public
    function Tuple: TArray<Variant>;
    function PoolId(const Value: TBytes32): TSingleSwap;
    function Kind(const Value: TSwapKind): TSingleSwap;
    function AssetIn(const Value: TAddress): TSingleSwap;
    function AssetOut(const Value: TAddress): TSingleSwap;
    function Amount(const Value: BigInteger): TSingleSwap;
  end;

  ISwapStep = interface end;

  TSwapStep = class(TInterfacedObject, IContractStruct, ISwapStep)
  private
    FPoolId       : TBytes32;
    FAssetInIndex : Integer;
    FAssetOutIndex: Integer;
    FAmount       : BigInteger;
  public
    function Tuple: TArray<Variant>;
    function PoolId(const Value: TBytes32): TSwapStep;
    function AssetInIndex(const Value: Integer): TSwapStep;
    function AssetOutIndex(const Value: Integer): TSwapStep;
    function Amount(const Value: BigInteger): TSwapStep;
  end;

  TOnSwap = reference to procedure(
    BlockNo  : BigInteger;
    PoolId   : TBytes32;
    TokenIn  : TAddress;
    TokenOut : TAddress;
    AmountIn : BigInteger;
    AmountOut: BigInteger);

  TVault = class(TCustomContract)
  public
    constructor Create(const aClient: IWeb3); reintroduce;
    class function DeployedAt: TAddress;
    procedure Swap(
      const owner   : TPrivateKey;
      const swap    : ISingleSwap;
      const limit   : BigInteger;
      const deadline: BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure BatchSwap(
      const owner   : TPrivateKey;
      const kind    : TSwapKind;
      const swaps   : TArray<ISwapStep>;
      const assets  : TArray<TAddress>;
      const limits  : TArray<BigInteger>;
      const deadline: BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure QueryBatchSwap(
      const owner   : TAddress;
      const kind    : TSwapKind;
      const swaps   : TArray<ISwapStep>;
      const assets  : TArray<TAddress>;
      const callback: TProc<TArray<BigInteger>, IError>);
    procedure WETH(const callback: TProc<TAddress, IError>);
  end;

// get the Balancer token list
procedure tokens(const chain: TChain; const callback: TProc<TTokens, IError>);

// easy access function: simulate a trade between two tokens, returning Vault asset deltas.
procedure simulate(
  const client  : IWeb3;
  const owner   : TAddress;
  const kind    : TSwapKind;
  const assetIn : TAddress;
  const assetOut: TAddress;
  const amount  : BigInteger;
  const callback: TProc<TArray<BigInteger>, IError>);

// easy access function: make a trade between two tokens.
procedure swap(
  const client  : IWeb3;
  const owner   : TPrivateKey; // owner of the tokens we are sending to the pool
  const kind    : TSwapKind;   // the type of swap we want to perform - either (a) "Given In" or (b) "Given Out"
  const assetIn : TAddress;    // the address of the token which we are sending to the pool
  const assetOut: TAddress;    // the address of the token which we will receive in return
  const amount  : BigInteger;  // the amount of tokens we (a) are sending to the pool, or (b) want to receive from the pool
  const limit   : BigInteger;  // the "other amount" aka (a) minimum amount of tokens to receive, or (b) maximum amount of tokens to send
  const deadline: BigInteger;  // your transaction will revert if it is still pending after this Unix epoch
  const callback: TProc<ITxReceipt, IError>);

// easy access function: listen for swaps between two tokens.
function listen(const client: IWeb3; const callback: TOnSwap): ILogger;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Types,
  // web3
  web3.eth,
  web3.eth.erc20,
  web3.graph,
  web3.json,
  web3.utils;

{ TSingleSwap }

function TSingleSwap.Tuple: TArray<Variant>;
begin
  Result := [
    web3.utils.toHex(Self.FPoolId), // bytes32
    Self.FKind,                     // uint8
    Self.FAssetIn,                  // address
    Self.FAssetOut,                 // address
    web3.utils.toHex(Self.FAmount), // uint256
    '0b0'                           // bytes
  ];
end;

function TSingleSwap.PoolId(const Value: TBytes32): TSingleSwap;
begin
  Self.FPoolId := Value;
  Result := Self;
end;

function TSingleSwap.Kind(const Value: TSwapKind): TSingleSwap;
begin
  Self.FKind := Value;
  Result := Self;
end;

function TSingleSwap.AssetIn(const Value: TAddress): TSingleSwap;
begin
  Self.FAssetIn := Value;
  Result := Self;
end;

function TSingleSwap.AssetOut(const Value: TAddress): TSingleSwap;
begin
  Self.FAssetOut := Value;
  Result := Self;
end;

function TSingleSwap.Amount(const Value: BigInteger): TSingleSwap;
begin
  Self.FAmount := Value;
  Result := Self;
end;

{ TSwapStep }

function TSwapStep.Tuple: TArray<Variant>;
begin
  Result := [
    web3.utils.toHex(Self.FPoolId), // bytes32
    Self.FAssetInIndex,             // uint256
    Self.FAssetOutIndex,            // uint256
    web3.utils.toHex(Self.FAmount), // uint256
    '0b0'                           // bytes
  ];
end;

function TSwapStep.PoolId(const Value: TBytes32): TSwapStep;
begin
  Self.FPoolId := Value;
  Result := Self;
end;

function TSwapStep.AssetInIndex(const Value: Integer): TSwapStep;
begin
  Self.FAssetInIndex := Value;
  Result := Self;
end;

function TSwapStep.AssetOutIndex(const Value: Integer): TSwapStep;
begin
  Self.FAssetOutIndex := Value;
  Result := Self;
end;

function TSwapStep.Amount(const Value: BigInteger): TSwapStep;
begin
  Self.FAmount := Value;
  Result := Self;
end;

{ TFundManagement }

type
  TFundManagement = class(TInterfacedObject, IContractStruct)
  private
    FSender: TAddress;
    FFromInternalBalance: Boolean;
    FRecipient: TAddress;
    FToInternalBalance: Boolean;
  public
    function Tuple: TArray<Variant>;
    property Sender             : TAddress write FSender;
    property FromInternalBalance: Boolean  write FFromInternalBalance;
    property Recipient          : TAddress write FRecipient;
    property ToInternalBalace   : Boolean  write FToInternalBalance;
  end;

function TFundManagement.Tuple: TArray<Variant>;
begin
  Result := [
    Self.FSender,              // address
    Self.FFromInternalBalance, // bool
    Self.FRecipient,           // address
    Self.FToInternalBalance    // bool
  ];
end;

{ TVault }

constructor TVault.Create(const aClient: IWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

class function TVault.DeployedAt: TAddress;
begin
  Result := '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
end;

procedure TVault.Swap(
  const owner   : TPrivateKey;
  const swap    : ISingleSwap;
  const limit   : BigInteger;
  const deadline: BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      const funds: IContractStruct = TFundManagement.Create;
      with funds as TFundManagement do
      begin
        Sender    := address.ToChecksum;
        Recipient := address.ToChecksum;
      end;
      web3.eth.write(Client, owner, Contract,
        'swap(' +
          '(bytes32,uint8,address,address,uint256,bytes),' + // SingleSwap
          '(address,bool,address,bool),' +                   // FundManagement
          'uint256,' +                                       // limit
          'uint256' +                                        // deadline
        ')',
        [swap, funds, web3.utils.toHex(limit), web3.utils.toHex(deadline)],
        callback
      );
    end);
end;

procedure TVault.BatchSwap(
  const owner   : TPrivateKey;
  const kind    : TSwapKind;
  const swaps   : TArray<ISwapStep>;
  const assets  : TArray<TAddress>;
  const limits  : TArray<BigInteger>;
  const deadline: BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      const funds: IContractStruct = TFundManagement.Create;
      with funds as TFundManagement do
      begin
        Sender    := address.ToChecksum;
        Recipient := address.ToChecksum;
      end;
      web3.eth.write(Client, owner, Contract,
        'batchSwap(' +
          'uint8,' +                                     // kind
          '(bytes32,uint256,uint256,uint256,bytes)[],' + // SwapSteps
          'address[],' +                                 // assets
          '(address,bool,address,bool),' +               // FundManagement
          'int256[],' +                                  // limits
          'uint256' +                                    // deadline
        ')',
        [
          Ord(kind),
          (
            function: TContractArray
            begin
              Result := TContractArray.Create;
              for var swap in swaps do Result.Add(swap);
            end
          )(),
          &array(assets),
          funds,
          &array(limits),
          web3.utils.toHex(deadline)
        ],
        callback
      );
    end);
end;

procedure TVault.QueryBatchSwap(
  const owner   : TAddress;
  const kind    : TSwapKind;
  const swaps   : TArray<ISwapStep>;
  const assets  : TArray<TAddress>;
  const callback: TProc<TArray<BigInteger>, IError>);
begin
  const funds: IContractStruct = TFundManagement.Create;
  with funds as TFundManagement do
  begin
    Sender    := owner.ToChecksum;
    Recipient := owner.ToChecksum;
  end;
  web3.eth.call(Client, owner, Contract,
    'queryBatchSwap(' +
      'uint8,' +                                     // kind
      '(bytes32,uint256,uint256,uint256,bytes)[],' + // SwapSteps
      'address[],' +                                 // assets
      '(address,bool,address,bool)' +                // FundManagement
    ')',
    [
      Ord(kind),
      (
        function: TContractArray
        begin
          Result := TContractArray.Create;
          for var swap in swaps do Result.Add(swap);
        end
      )(),
      &array(assets),
      funds
    ],
    procedure(tup: TTuple; err: IError)
    begin
      callback(
        (
          function: TArray<BigInteger>
          begin
            Result := [];
            if Assigned(tup) then
              for var arg in tup.ToArray do Result := Result + [arg.toInt256];
          end
        )(),
        err
      );
    end
  );
end;

procedure TVault.WETH(const callback: TProc<TAddress, IError>);
begin
  call(Client, Contract, 'WETH()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

{----------- get the pool id for a single swap between two tokens -------------}

type
  IPoolDoesNotExist = interface(IError)
  ['{98E7E985-B74E-4D20-84A4-E8A2F8060D56}']
  end;

type
  TPoolDoesNotExist = class(TError, IPoolDoesNotExist)
  public
    constructor Create;
  end;

constructor TPoolDoesNotExist.Create;
begin
  inherited Create('Pool does not exist');
end;

procedure getPoolId(const chain: TChain; const asset0, asset1: TAddress; const callback: TProc<string, IError>);
const
  QUERY = '{"query":"{pools(where: {tokensList: [\"%s\", \"%s\"]}, orderBy: totalLiquidity, orderDirection: desc) { id }}"}';
begin
  const execute = procedure(token0, token1: TAddress; callback: TProc<string, IError>)
  begin
    const SUBGRAPH = (function(chain: TChain): IResult<string>
    begin
      if chain = Ethereum then
        Result := TResult<string>.Ok('https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-v2')
      else if chain = Goerli then
        Result := TResult<string>.Ok('https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-goerli-v2')
      else if chain = Polygon then
        Result := TResult<string>.Ok('https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-polygon-v2')
      else if chain = Arbitrum then
        Result := TResult<string>.Ok('https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-arbitrum-v2')
      else
        Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
    end)(chain);
    if SUBGRAPH.isErr then
    begin
      callback('', SUBGRAPH.Error);
      EXIT;
    end;
    web3.graph.execute(SUBGRAPH.Value, Format(QUERY, [string(token0), string(token1)]), procedure(response: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        callback('', err);
        EXIT;
      end;
      const data = web3.json.getPropAsObj(response, 'data');
      if Assigned(data) then
      begin
        const pools = web3.json.getPropAsArr(data, 'pools');
        if Assigned(pools) and (pools.Count > 0) then
        begin
          callback(web3.json.getPropAsStr(pools[0], 'id'), nil);
          EXIT;
        end;
      end;
      callback('', TPoolDoesNotExist.Create);
    end);
  end;
  execute(asset0, asset1, procedure(id: string; err: IError)
  begin
    if Assigned(err) and Supports(err, IPoolDoesNotExist) then
      execute(asset1, asset0, callback)
    else
      callback(id, err);
  end);
end;

{------------------------ get the Balancer token list -------------------------}

procedure tokens(const chain: TChain; const callback: TProc<TTokens, IError>);
begin
  if (chain = Ethereum) or (chain = Goerli) then
  begin
    web3.eth.tokenlists.tokens((function: TURL
    begin
      if chain = Goerli then
        Result := 'https://raw.githubusercontent.com/svanas/delphereum/master/web3.eth.balancer.v2.tokenlist.goerli.json'
      else
        Result := 'https://raw.githubusercontent.com/balancer-labs/assets/master/generated/listed.tokenlist.json';
    end)(), procedure(tokens: TTokens; err: IError)
    begin
      if Assigned(err) or not Assigned(tokens) then
      begin
        callback(nil, err);
        EXIT;
      end;
      var I := 0;
      while I < tokens.Length do
        if tokens[I].ChainId <> chain.Id then
          Delete(tokens, I, 1)
        else
          Inc(I);
      callback(tokens, nil);
    end);
    EXIT;
  end;
  web3.eth.tokenlists.tokens(chain, callback);
end;

{---------- easy access function: returns the Vault's WETH instance -----------}

procedure weth(const client: IWeb3; const callback: TProc<TAddress, IError>);
begin
  const vault = TVault.Create(client);
  try
    vault.WETH(callback);
  finally
    vault.Free;
  end;
end;

{-------------- router function: computes the steps for a trade ---------------}

type
  IPool = interface
    function Id      : TBytes32;
    function AssetIn : TAddress;
    function AssetOut: TAddress;
  end;

  TPool = class(TInterfacedObject, IPool)
  strict private
    FId      : TBytes32;
    FAssetIn : TAddress;
    FAssetOut: TAddress;
  public
    constructor Create(const aId: TBytes32; const aAssetIn, aAssetOut: TAddress);
    function Id      : TBytes32;
    function AssetIn : TAddress;
    function AssetOut: TAddress;
  end;

constructor TPool.Create(const aId: TBytes32; const aAssetIn, aAssetOut: TAddress);
begin
  inherited Create;
  Self.FId       := aId;
  Self.FAssetIn  := aAssetIn;
  Self.FAssetOut := aAssetOut;
end;

function TPool.Id: TBytes32;
begin
  Result := FId;
end;

function TPool.AssetIn: TAddress;
begin
  Result := FAssetIn;
end;

function TPool.AssetOut: TAddress;
begin
  Result := FAssetOut;
end;

type
  IPools = interface
    function First: IPool;
    function Length: Integer;
    function ToAssets: TArray<TAddress>;
    function ToLimits(const kind: TSwapKind; const limit: BigInteger): TArray<BigInteger>;
    function ToSwapSteps(const kind: TSwapKind; const amount: BigInteger): TArray<ISwapStep>;
  end;

  TPools = class(TInterfacedObject, IPools)
  strict private
    Inner: TArray<IPool>;
  public
    constructor Create(const pools: TArray<IPool>);
    function First: IPool;
    function Length: Integer;
    function ToAssets: TArray<TAddress>;
    function ToLimits(const kind: TSwapKind; const limit: BigInteger): TArray<BigInteger>;
    function ToSwapSteps(const kind: TSwapKind; const amount: BigInteger): TArray<ISwapStep>;
  end;

constructor TPools.Create(const pools: TArray<IPool>);
begin
  inherited Create;
  Self.Inner := pools;
end;

function TPools.First: IPool;
begin
  if Self.Length > 0 then
    Result := Self.Inner[0]
  else
    Result := nil;
end;

function TPools.Length: Integer;
begin
  Result := System.Length(Self.Inner);
end;

function TPools.ToAssets: TArray<TAddress>;
begin
  Result := [];
  if Self.Length = 0 then
    EXIT;
  for var I := 0 to Pred(Self.Length) do
    Result := Result + [Self.Inner[I].AssetIn];
  Result := Result + [Self.Inner[High(Self.Inner)].AssetOut];
end;

// returns the minimum or maximum amount of each token the vault is allowed to transfer
function TPools.ToLimits(const kind: TSwapKind; const limit: BigInteger): TArray<BigInteger>;
begin
  Result := [];
  if Self.Length = 0 then
    EXIT;
  SetLength(Result, Self.Length + 1);
  if Kind = GivenOut then
  begin
    // maximum number of tokens to send
    Result[0] := (function: BigInteger
    begin
      if limit.IsZero then
        Result := web3.MaxInt256
      else if limit.IsNegative then
        Result := BigInteger.Abs(limit)
      else
        Result := limit;
    end)();
    // minimum amount of tokens to receive
    Result[High(Result)] := 0;
  end
  else
  begin
    // maximum number of tokens to send
    Result[0] := web3.MaxInt256;
    // minimum amount of tokens to receive
    Result[High(Result)] := (function: BigInteger
    begin
      if limit.IsZero or limit.IsNegative then
        Result := limit
      else
        Result := BigInteger.Negate(limit);
    end)();
  end;
end;

function TPools.ToSwapSteps(const kind: TSwapKind; const amount: BigInteger): TArray<ISwapStep>;
begin
  Result := [];
  if Self.Length = 0 then
    EXIT;
  var I := 0;
  if kind = GivenOut then
    I := High(Self.Inner);
  while ((kind = GivenOut) and (I > -1)) or ((kind = GivenIn) and (I < Self.Length)) do
  begin
    Result := Result + [
      TSwapStep.Create
        .PoolId(Self.Inner[I].Id)
        .AssetInIndex(I)
        .AssetOutIndex(I + 1)
        .Amount((function: BigInteger
        begin
          if ((kind = GivenIn) and (I = 0)) or ((kind = GivenOut) and (I = High(Self.Inner))) then
            Result := amount
          else
            Result := 0;
        end)())
    ];
    if kind = GivenOut then
      Dec(I)
    else
      Inc(I);
  end;
end;

procedure getPools(
  const client  : IWeb3;
  const assetIn : TAddress;
  const assetOut: TAddress;
  const callback: TProc<IPools, IError>);
begin
  // step #1: get the pool id for a single swap
  getPoolId(client.Chain, assetIn, assetOut, procedure(poolId: string; err: IError)
  begin
    if not Assigned(err) then
      callback(TPools.Create([
        TPool.Create(web3.utils.fromHex32(poolId), assetIn, assetOut)
      ]), nil)
    else
      // step #2: get the Vault's WETH instance
      weth(client, procedure(weth: TAddress; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          if assetIn.SameAs(weth) or assetOut.SameAs(weth) then
            callback(nil, TPoolDoesNotExist.Create)
          else
            // step #3: get the pool IDs for a batch swap
            getPoolId(client.Chain, assetIn, weth, procedure(pool1: string; err: IError)
            begin
              if Assigned(err) then
                callback(nil, err)
              else
                getPoolId(client.Chain, weth, assetOut, procedure(pool2: string; err: IError)
                begin
                  if Assigned(err) then
                    callback(nil, err)
                  else
                    callback(TPools.Create([
                      TPool.Create(web3.utils.fromHex32(pool1), assetIn, weth),
                      TPool.Create(web3.utils.fromHex32(pool2), weth, assetOut)
                    ]), nil);
                end);
            end);
      end);
  end);
end;

{--------- easy access function: simulate a trade between two tokens ----------}

procedure simulate(
  const client  : IWeb3;
  const owner   : TAddress;
  const kind    : TSwapKind;
  const assetIn : TAddress;
  const assetOut: TAddress;
  const amount  : BigInteger;
  const callback: TProc<TArray<BigInteger>, IError>);
begin
  // step #1: get the pool IDs for a trade
  getPools(client, assetIn, assetOut, procedure(pools: IPools; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // step #2: simulate a call to `batchSwap`
    const vault = TVault.Create(client);
    try
      vault.QueryBatchSwap(
        owner,
        kind,
        pools.ToSwapSteps(kind, amount),
        pools.ToAssets,
        callback
      );
    finally
      vault.Free;
    end;
  end);
end;

{----------- easy access function: make a trade between two tokens ------------}

procedure swap(
  const client  : IWeb3;
  const owner   : TPrivateKey;
  const kind    : TSwapKind;
  const assetIn : TAddress;
  const assetOut: TAddress;
  const amount  : BigInteger;
  const limit   : BigInteger;
  const deadline: BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  // step #1: get the pool IDs for a trade
  getPools(client, assetIn, assetOut, procedure(pools: IPools; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // step #2: grant token spend allowance to the vault
    web3.eth.erc20.approve(web3.eth.erc20.Create(client, assetIn), owner, TVault.DeployedAt, web3.Infinite, procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      // step #3: execute a swap
      const vault = TVault.Create(client);
      try
        if pools.Length > 1 then
          // execute a batch swap
          vault.BatchSwap(
            owner,
            kind,
            pools.ToSwapSteps(kind, amount),
            pools.ToAssets,
            pools.ToLimits(kind, limit),
            deadline,
            callback
          )
        else
          // execute a single swap, saving ~6,000 gas
          vault.Swap(
            owner,
            // initialize which pool we're trading with and what kind of swap we want to perform
            TSingleSwap.Create
              .PoolId(pools.First.Id)
              .Kind(kind)
              .AssetIn(assetIn)
              .AssetOut(assetOut)
              .Amount(amount),
            (
              function: BigInteger
              begin
                if limit.IsZero then
                begin
                  if kind = GivenOut then
                    Result := web3.Infinite
                  else
                    Result := limit;
                end
                else
                  Result := BigInteger.Abs(limit);
              end
            )(),
            deadline,
            callback
          );
      finally
        vault.Free;
      end;
    end);
  end);
end;

{---------- easy access function: listen for swaps between two tokens ---------}

function listen(const client: IWeb3; const callback: TOnSwap): ILogger;
begin
  Result := web3.eth.logs.get(client, TVault.DeployedAt, procedure(log: PLog; err: IError)
  begin
    if Assigned(log) and Assigned(callback) then
      if log^.isEvent('Swap(bytes32,address,address,uint256,uint256)') then
        callback(log^.BlockNumber,        // blockNo
                 log^.Topic[1].toBytes32, // poolId
                 log^.Topic[2].toAddress, // tokenIn
                 log^.Topic[3].toAddress, // tokenOut
                 log^.Data[0].toUInt256,  // amountIn
                 log^.Data[1].toUInt256); // amountOut
  end);
end;

end.
