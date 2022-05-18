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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.abi,
  web3.eth.contract,
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
    function PoolId(Value: TBytes32): TSingleSwap;
    function Kind(Value: TSwapKind): TSingleSwap;
    function AssetIn(Value: TAddress): TSingleSwap;
    function AssetOut(Value: TAddress): TSingleSwap;
    function Amount(Value: BigInteger): TSingleSwap;
  end;

  TVault = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    class function DeployedAt: TAddress;
    procedure Swap(
      owner   : TPrivateKey;
      swap    : ISingleSwap;
      limit   : BigInteger;
      deadline: BigInteger;
      callback: TAsyncReceipt);
  end;

// get the pool id for a single swap between two tokens
procedure getPoolId(chain: TChain; asset0, asset1: TAddress; callback: TAsyncString);

// get the Balancer token list
procedure tokens(chain: TChain; callback: TAsyncTokens);

// easy access function: make a trade between two tokens in one pool, saving ~6,000 gas.
procedure swap(
  client  : IWeb3;
  owner   : TPrivateKey; // owner of the tokens we are sending to the pool
  kind    : TSwapKind;   // the type of swap we want to perform - either (a) "Given In" or (b) "Given Out"
  assetIn : TAddress;    // the address of the token which we are sending to the pool
  assetOut: TAddress;    // the address of the token which we will receive in return
  amount  : BigInteger;  // the amount of tokens we (a) are sending to the pool, or (b) want to receive from the pool
  deadline: BigInteger;  // your transaction will revert if it is still pending after this Unix epoch
  callback: TAsyncReceipt);

implementation

{$R 'web3.eth.balancer.v2.tokenlist.kovan.res'}

uses
  // Delphi
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
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
    ''                              // bytes
  ];
end;

function TSingleSwap.PoolId(Value: TBytes32): TSingleSwap;
begin
  Self.FPoolId := Value;
  Result := Self;
end;

function TSingleSwap.Kind(Value: TSwapKind): TSingleSwap;
begin
  Self.FKind := Value;
  Result := Self;
end;

function TSingleSwap.AssetIn(Value: TAddress): TSingleSwap;
begin
  Self.FAssetIn := Value;
  Result := Self;
end;

function TSingleSwap.AssetOut(Value: TAddress): TSingleSwap;
begin
  Self.FAssetOut := Value;
  Result := Self;
end;

function TSingleSwap.Amount(Value: BigInteger): TSingleSwap;
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

constructor TVault.Create(aClient: IWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

class function TVault.DeployedAt: TAddress;
begin
  Result := '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
end;

procedure TVault.Swap(
  owner   : TPrivateKey;
  swap    : ISingleSwap;
  limit   : BigInteger;
  deadline: BigInteger;
  callback: TAsyncReceipt);
begin
  owner.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var funds: IContractStruct := TFundManagement.Create;
    with funds as TFundManagement do
    begin
      Sender    := addr.ToChecksum;
      Recipient := addr.ToChecksum;
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

procedure getPoolId(chain: TChain; asset0, asset1: TAddress; callback: TAsyncString);
const
  QUERY = '{"query":"{pools(where: {tokensList: [\"%s\", \"%s\"]}, orderBy: totalLiquidity, orderDirection: desc) { id }}"}';
const
  SUBGRAPH: array[TChain] of string = (
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-v2',          // Ethereum,
    '',                                                                           // Ropsten
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-rinkeby-v2',  // Rinkeby
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-kovan-v2',    // Kovan
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-goerli-v2',   // Goerli
    '',                                                                           // Optimism
    '',                                                                           // Optimism_test_net
    '',                                                                           // RSK
    '',                                                                           // RSK_test_net
    '',                                                                           // BSC
    '',                                                                           // BSC_test_net
    '',                                                                           // Gnosis
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-polygon-v2',  // Polygon
    '',                                                                           // Polygon_test_net
    '',                                                                           // Fantom
    '',                                                                           // Fantom_test_net
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-arbitrum-v2', // Arbitrum
    ''                                                                            // Arbitrum_test_net
  );
begin
  var execute := procedure(token0, token1: TAddress; callback: TAsyncString)
  begin
    web3.graph.execute(SUBGRAPH[chain], Format(QUERY, [string(token0), string(token1)]), procedure(resp: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        callback('', err);
        EXIT;
      end;
      var data := web3.json.getPropAsObj(resp, 'data');
      if Assigned(data) then
      begin
        var pools := web3.json.getPropAsArr(data, 'pools');
        if Assigned(pools) and (pools.Count > 0) then
        begin
          callback(web3.json.getPropAsStr(pools[0], 'id'), nil);
          EXIT;
        end;
      end;
      callback('', TPoolDoesNotExist.Create);
    end);
  end;
  execute(asset0, asset1, procedure(const id: string; err: IError)
  begin
    if Assigned(err) and Supports(err, IPoolDoesNotExist) then
      execute(asset1, asset0, callback)
    else
      callback(id, err);
  end);
end;

{------------------------ get the Balancer token list -------------------------}

procedure tokens(chain: TChain; callback: TAsyncTokens);
begin
  if chain = Kovan then
  begin
    var tokens: TTokens;
    var RS := TResourceStream.Create(hInstance, 'BALANCER_V2_TOKENLIST_KOVAN', RT_RCDATA);
    try
      var buf: TBytes;
      SetLength(buf, RS.Size);
      RS.Read(buf[0], RS.Size);
      var arr := TJsonObject.ParseJsonValue(TEncoding.UTF8.GetString(buf)) as TJsonArray;
      if Assigned(arr) then
      try
        for var token in arr do
          tokens := tokens + [web3.eth.tokenlists.token(token as TJsonObject)];
      finally
        arr.Free;
      end;
    finally
      RS.Free;
    end;
    callback(tokens, nil);
    EXIT;
  end;
  web3.eth.tokenlists.tokens('https://raw.githubusercontent.com/balancer-labs/assets/master/generated/listed.tokenlist.json', procedure(tokens: TTokens; err: IError)
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
end;

{----- easy access function: make a trade between two tokens in one pool ------}

procedure swap(
  client  : IWeb3;
  owner   : TPrivateKey;
  kind    : TSwapKind;
  assetIn : TAddress;
  assetOut: TAddress;
  amount  : BigInteger;
  deadline: BigInteger;
  callback: TAsyncReceipt);
begin
  // step #1: get the pool id for a single swap
  getPoolId(client.Chain, assetIn, assetOut, procedure(const poolId: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // step #2: grant token spend allowance to the vault
    TERC20.Create(client, assetIn).ApproveEx(owner, TVault.DeployedAt, web3.Infinite, procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      // step #3: initialize which pool we're trading with and what kind of swap we want to perform
      var vault := TVault.Create(client);
      try
        // step #4: execute a single swap
        vault.Swap(
          owner,
          TSingleSwap.Create
            .PoolId(web3.utils.fromHex32(poolId))
            .Kind(kind)
            .AssetIn(assetIn)
            .AssetOut(assetOut)
            .Amount(amount),
          0,
          deadline,
          callback
        );
      finally
        vault.Free;
      end;
    end);
  end);
end;

end.
