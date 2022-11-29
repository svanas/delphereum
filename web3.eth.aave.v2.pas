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
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types;

type
  TAave = class(TLendingProtocol)
  protected
    class procedure UNDERLYING_TO_TOKEN(
      client  : IWeb3;
      reserve : TReserve;
      callback: TProc<TAddress, IError>);
    class procedure TOKEN_TO_UNDERLYING(
      client  : IWeb3;
      atoken  : TAddress;
      callback: TProc<TAddress, IError>);
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client  : IWeb3;
      reserve : TReserve;
      _period : TPeriod;
      callback: TProc<Double, IError>); override;
    class procedure Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>); override;
    class procedure Balance(
      client  : IWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TProc<BigInteger, IError>); override;
    class procedure Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TProc<ITxReceipt, BigInteger, IError>); override;
    class procedure WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, BigInteger, IError>); override;
  end;

  TAaveLendingPool = class(TCustomContract)
  protected
    procedure GetReserveData(reserve: TReserve; callback: TProc<TTuple, IError>);
  public
    procedure Deposit(
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
    procedure CurrentLiquidityRate(reserve: TReserve; callback: TProc<BigInteger, IError>);
  end;

  TAaveProtocolDataProvider = class(TCustomContract)
    procedure GetReserveTokensAddresses(
      reserve : TReserve;
      callback: TProc<TTuple, IError>);
  end;

  TAaveLendingPoolAddressesProvider = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure GetLendingPool(callback: TProc<TAddress, IError>);
    procedure GetAddress(id: TBytes32; callback: TProc<TAddress, IError>);
    procedure GetProtocolDataProvider(callback: TProc<TAddress, IError>);
  end;

  TaToken = class(TERC20)
  public
    procedure UNDERLYING_ASSET_ADDRESS(callback: TProc<TAddress, IError>);
  end;

implementation

uses
  // web3
  web3.eth,
  web3.utils,
  // Delphi
  System.TypInfo;

{ TAave }

class procedure TAave.UNDERLYING_TO_TOKEN(
  client  : IWeb3;
  reserve : TReserve;
  callback: TProc<TAddress, IError>);
begin
  const ap = TAaveLendingPoolAddressesProvider.Create(client);
  try
    ap.GetProtocolDataProvider(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(EMPTY_ADDRESS, err);
        EXIT;
      end;
      const dp = TAaveProtocolDataProvider.Create(client, addr);
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
  callback: TProc<TAddress, IError>);
begin
  const erc20 = TaToken.Create(client, atoken);
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
  callback: TProc<ITxReceipt, IError>);
begin
  const AP = TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(AP) then
  try
    AP.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      const underlying = reserve.Address(client.chain);
      if underlying.IsErr then
      begin
        callback(nil, underlying.Error);
        EXIT;
      end;
      const erc20 = TERC20.Create(client, underlying.Value);
      if Assigned(erc20) then
      begin
        erc20.ApproveEx(from, pool, amount, procedure(rcpt: ITxReceipt; err: IError)
        begin
          try
            callback(rcpt, err);
          finally
            erc20.Free;
          end;
        end);
      end;
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
  Result := (chain = Ethereum) and (reserve in [DAI, USDC, USDT, TUSD]);
end;

class procedure TAave.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TProc<Double, IError>);
begin
  const AP = TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(AP) then
  try
    AP.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      const LP = TAaveLendingPool.Create(client, pool);
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
  callback: TProc<ITxReceipt, IError>);
begin
  // Before supplying an asset, we must first approve the LendingPool contract.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const AP = TAaveLendingPoolAddressesProvider.Create(client);
    if Assigned(AP) then
    try
      AP.GetLendingPool(procedure(pool: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        const LP = TAaveLendingPool.Create(client, pool);
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
  callback: TProc<BigInteger, IError>);
begin
  Self.UNDERLYING_TO_TOKEN(client, reserve, procedure(atoken: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    const erc20 = TaToken.Create(client, atoken);
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
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const owner = from.GetAddress;
  if owner.IsErr then
    callback(nil, 0, owner.Error)
  else
    Self.Balance(client, owner.Value, reserve, procedure(amount: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        Self.WithdrawEx(client, from, reserve, amount, callback);
    end);
end;

class procedure TAave.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const AP = TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(AP) then
  try
    AP.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, 0, err);
        EXIT;
      end;
      const LP = TAaveLendingPool.Create(client, pool);
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
  callback: TProc<ITxReceipt, IError>);
begin
  const underlying = reserve.Address(Client.Chain);
  if underlying.IsErr then
  begin
    callback(nil, underlying.Error);
    EXIT;
  end;
  const receiver = from.GetAddress;
  if receiver.IsErr then
    callback(nil, receiver.Error)
  else
    web3.eth.write(
      Self.Client,
      from,
      Self.Contract,
      'deposit(address,uint256,address,uint16)',
      [underlying.Value, web3.utils.toHex(amount), receiver.Value, 42],
      callback);
end;

procedure TAaveLendingPool.Withdraw(
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const underlying = reserve.Address(Client.Chain);
  if underlying.IsErr then
  begin
    callback(nil, underlying.Error);
    EXIT;
  end;
  const receiver = from.GetAddress;
  if receiver.IsErr then
    callback(nil, receiver.Error)
  else
    web3.eth.write(
      Self.Client,
      from,
      Self.Contract,
      'withdraw(address,uint256,address)',
      [underlying.Value, web3.utils.toHex(amount), receiver.Value],
      callback);
end;

procedure TAaveLendingPool.GetReserveData(reserve: TReserve; callback: TProc<TTuple, IError>);
begin
  const underlying = reserve.Address(Client.Chain);
  if underlying.IsErr then
    callback(nil, underlying.Error)
  else
    web3.eth.call(Client, Contract, 'getReserveData(address)', [underlying.Value], callback);
end;

procedure TAaveLendingPool.CurrentLiquidityRate(reserve: TReserve; callback: TProc<BigInteger, IError>);
begin
  GetReserveData(reserve, procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(tup[3].toUInt256, nil);
  end);
end;

{ TAaveProtocolDataProvider }

procedure TAaveProtocolDataProvider.GetReserveTokensAddresses(
  reserve : TReserve;
  callback: TProc<TTuple, IError>);
begin
  const underlying = reserve.Address(Client.Chain);
  if underlying.IsErr then
    callback(nil, underlying.Error)
  else
    web3.eth.call(Client, Contract, 'getReserveTokensAddresses(address)', [underlying.Value], callback);
end;

{ TAaveLendingPoolAddressesProvider }

constructor TAaveLendingPoolAddressesProvider.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5');
end;

procedure TAaveLendingPoolAddressesProvider.GetLendingPool(callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'getLendingPool()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure TAaveLendingPoolAddressesProvider.GetAddress(id: TBytes32; callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'getAddress(bytes32)', [web3.utils.toHex(id)], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure TAaveLendingPoolAddressesProvider.GetProtocolDataProvider(callback: TProc<TAddress, IError>);
const
  id: TBytes32 = (1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
begin
  Self.GetAddress(id, callback);
end;

{ TaToken }

procedure TaToken.UNDERLYING_ASSET_ADDRESS(callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'UNDERLYING_ASSET_ADDRESS()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

end.
