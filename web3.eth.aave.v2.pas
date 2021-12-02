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

unit web3.eth.aave.v2;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types;

type
  EAave = class(EWeb3);

type
  TAave = class(TLendingProtocol)
  protected
    class procedure GET_RESERVE_ADDRESS(
      chain   : TChain;
      reserve : TReserve;
      callback: TAsyncAddress);
    class procedure UNDERLYING_TO_TOKEN(
      client  : IWeb3;
      reserve : TReserve;
      callback: TAsyncAddress);
    class procedure TOKEN_TO_UNDERLYING(
      client  : IWeb3;
      atoken  : TAddress;
      callback: TAsyncAddress);
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client  : IWeb3;
      reserve : TReserve;
      _period : TPeriod;
      callback: TAsyncFloat); override;
    class procedure Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); override;
    class procedure Balance(
      client  : IWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); override;
    class procedure Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceiptEx); override;
    class procedure WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceiptEx); override;
  end;

type
  TAaveLendingPool = class(TCustomContract)
  protected
    procedure GetReserveData(reserve: TReserve; callback: TAsyncTuple);
  public
    procedure Deposit(
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    procedure Withdraw(
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    procedure CurrentLiquidityRate(reserve: TReserve; callback: TAsyncQuantity);
  end;

type
  TAaveProtocolDataProvider = class(TCustomContract)
    procedure GetReserveTokensAddresses(
      reserve : TReserve;
      callback: TAsyncTuple);
  end;

type
  TAaveLendingPoolAddressesProvider = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure GetLendingPool(callback: TAsyncAddress);
    procedure GetAddress(id: TBytes32; callback: TAsyncAddress);
    procedure GetProtocolDataProvider(callback: TAsyncAddress);
  end;

type
  TaToken = class(TERC20)
  public
    procedure UNDERLYING_ASSET_ADDRESS(callback: TAsyncAddress);
  end;

implementation

uses
  // web3
  web3.eth,
  web3.utils,
  // Delphi
  System.TypInfo;

{ TAave }

class procedure TAave.GET_RESERVE_ADDRESS(
  chain   : TChain;
  reserve : TReserve;
  callback: TAsyncAddress);
begin
  if chain = Mainnet then
  begin
    callback(reserve.Address, nil);
    EXIT;
  end;
  if (chain = Kovan) and (reserve in [DAI, USDC, USDT]) then
  begin
    case reserve of
      DAI : callback('0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD', nil);
      USDC: callback('0xe22da380ee6B445bb8273C81944ADEB6E8450422', nil);
      USDT: callback('0x13512979ADE267AB5100878E2e0f485B568328a4', nil);
    end;
    EXIT;
  end;
  callback(EMPTY_ADDRESS,
    TError.Create('%s is not supported on %s', [
      GetEnumName(TypeInfo(TReserve), Ord(reserve)), GetEnumName(TypeInfo(TChain), Ord(chain))
    ])
  );
end;

class procedure TAave.UNDERLYING_TO_TOKEN(
  client  : IWeb3;
  reserve : TReserve;
  callback: TAsyncAddress);
begin
  var ap := TAaveLendingPoolAddressesProvider.Create(client);
  try
    ap.GetProtocolDataProvider(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(EMPTY_ADDRESS, err);
        EXIT;
      end;
      var dp := TAaveProtocolDataProvider.Create(client, addr);
      try
        dp.GetReserveTokensAddresses(reserve, procedure(tup: TTuple; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(EMPTY_ADDRESS, err);
            EXIT;
          end;
          if Length(tup) = 0 then
            callback(EMPTY_ADDRESS, nil)
          else
            callback(tup[0].toAddress, nil);
        end);
      finally
        dp.Free;
      end;
    end);
  finally
    ap.Free;
  end;
end;

class procedure TAave.TOKEN_TO_UNDERLYING(
  client  : IWeb3;
  atoken  : TAddress;
  callback: TAsyncAddress);
begin
  var erc20 := TaToken.Create(client, atoken);
  try
    erc20.UNDERLYING_ASSET_ADDRESS(callback);
  finally
    erc20.Free;
  end;
end;

class procedure TAave.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  var AP := TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(AP) then
  try
    AP.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      Self.GET_RESERVE_ADDRESS(client.chain, reserve, procedure(asset: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        var underlying := TERC20.Create(client, asset);
        if Assigned(underlying) then
        begin
          underlying.ApproveEx(from, pool, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            try
              callback(rcpt, err);
            finally
              underlying.Free;
            end;
          end);
        end;
      end);
    end);
  finally
    AP.Free;
  end;
end;

class function TAave.Name: string;
begin
  Result := 'Aave';
end;

class function TAave.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain in [Mainnet, Kovan]) and (reserve in [DAI, USDC, USDT]);
end;

class procedure TAave.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TAsyncFloat);
begin
  var AP := TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(AP) then
  try
    AP.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      var LP := TAaveLendingPool.Create(client, pool);
      if Assigned(LP) then
      try
        LP.CurrentLiquidityRate(reserve, procedure(qty: BigInteger; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(0, err);
            EXIT;
          end;
          callback(BigInteger.Divide(qty, BigInteger.Create(1e21)).AsInt64 / 1e4, nil);
        end);
      finally
        LP.Free;
      end;
    end);
  finally
    AP.Free;
  end;
end;

class procedure TAave.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  // Before supplying an asset, we must first approve the LendingPool contract.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var AP := TAaveLendingPoolAddressesProvider.Create(client);
    if Assigned(AP) then
    try
      AP.GetLendingPool(procedure(pool: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        var LP := TAaveLendingPool.Create(client, pool);
        if Assigned(LP) then
        try
          LP.Deposit(from, reserve, amount, callback);
        finally
          LP.Free;
        end;
      end);
    finally
      AP.Free;
    end;
  end);
end;

class procedure TAave.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  Self.UNDERLYING_TO_TOKEN(client, reserve, procedure(atoken: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    var erc20 := TaToken.Create(client, atoken);
    if Assigned(erc20) then
    try
      erc20.BalanceOf(owner, callback);
    finally
      erc20.Free;
    end;
  end);
end;

class procedure TAave.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  from.Address(procedure(owner: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    Self.Balance(client, owner, reserve, procedure(amount: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, 0, err);
        EXIT;
      end;
      Self.WithdrawEx(client, from, reserve, amount, callback);
    end);
  end);
end;

class procedure TAave.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  var AP := TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(AP) then
  try
    AP.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, 0, err);
        EXIT;
      end;
      var LP := TAaveLendingPool.Create(client, pool);
      if Assigned(LP) then
      try
        LP.Withdraw(from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          callback(rcpt, amount, nil);
        end);
      finally
        LP.Free;
      end;
    end);
  finally
    AP.Free;
  end;
end;

{ TAaveLendingPool }

procedure TAaveLendingPool.Deposit(
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  TAave.GET_RESERVE_ADDRESS(Client.Chain, reserve, procedure(asset: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    from.Address(procedure(receiver: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      web3.eth.write(
        Self.Client,
        from,
        Self.Contract,
        'deposit(address,uint256,address,uint16)',
        [asset, web3.utils.toHex(amount), receiver, 42],
        callback);
    end);
  end);
end;

procedure TAaveLendingPool.Withdraw(
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  TAave.GET_RESERVE_ADDRESS(Client.Chain, reserve, procedure(asset: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    from.Address(procedure(receiver: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      web3.eth.write(
        Self.Client,
        from,
        Self.Contract,
        'withdraw(address,uint256,address)',
        [asset, web3.utils.toHex(amount), receiver],
        callback);
    end);
  end);
end;

procedure TAaveLendingPool.GetReserveData(reserve: TReserve; callback: TAsyncTuple);
begin
  TAave.GET_RESERVE_ADDRESS(Client.Chain, reserve, procedure(asset: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.call(Client, Contract, 'getReserveData(address)', [asset], callback);
  end);
end;

procedure TAaveLendingPool.CurrentLiquidityRate(reserve: TReserve; callback: TAsyncQuantity);
begin
  GetReserveData(reserve, procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(tup[3].toBigInt, nil);
  end);
end;

{ TAaveProtocolDataProvider }

procedure TAaveProtocolDataProvider.GetReserveTokensAddresses(
  reserve : TReserve;
  callback: TAsyncTuple);
begin
  TAave.GET_RESERVE_ADDRESS(Client.Chain, reserve, procedure(asset: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    web3.eth.call(Client, Contract, 'getReserveTokensAddresses(address)', [asset], callback);
  end);
end;

{ TAaveLendingPoolAddressesProvider }

constructor TAaveLendingPoolAddressesProvider.Create(aClient: IWeb3);
begin
  if aClient.Chain = Mainnet then
    inherited Create(aClient, '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5')
  else
    if aClient.Chain = Kovan then
      inherited Create(aClient, '0x652B2937Efd0B5beA1c8d54293FC1289672AFC6b')
    else
      raise EAave.CreateFmt('Aave is not deployed on %s', [GetEnumName(TypeInfo(TChain), Integer(aClient.Chain))]);
end;

procedure TAaveLendingPoolAddressesProvider.GetLendingPool(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'getLendingPool()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

procedure TAaveLendingPoolAddressesProvider.GetAddress(id: TBytes32; callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'getAddress(bytes32)', [web3.utils.toHex(id)], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

procedure TAaveLendingPoolAddressesProvider.GetProtocolDataProvider(callback: TAsyncAddress);
const
  id: TBytes32 = (1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
begin
  Self.GetAddress(id, callback);
end;

{ TaToken }

procedure TaToken.UNDERLYING_ASSET_ADDRESS(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'UNDERLYING_ASSET_ADDRESS()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

end.
