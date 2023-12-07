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
  web3.eth,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.etherscan,
  web3.eth.types,
  web3.utils;

type
  TAave = class(TLendingProtocol)
  protected
    class procedure UNDERLYING_TO_TOKEN(
      const client  : IWeb3;
      const reserve : TReserve;
      const callback: TProc<TAddress, IError>);
    class procedure TOKEN_TO_UNDERLYING(
      const client  : IWeb3;
      const token   : TAddress;
      const callback: TProc<TAddress, IError>);
    class procedure Approve(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
  public
    class function Name: string; override;
    class function Supports(
      const chain  : TChain;
      const reserve: TReserve): Boolean; override;
    class procedure APY(
      const client   : IWeb3;
      const etherscan: IEtherscan;
      const reserve  : TReserve;
      const period   : TPeriod;
      const callback : TProc<Double, IError>); override;
    class procedure Deposit(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>); override;
    class procedure Balance(
      const client  : IWeb3;
      const owner   : TAddress;
      const reserve : TReserve;
      const callback: TProc<BigInteger, IError>); override;
    class procedure Withdraw(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const callback: TProc<ITxReceipt, BigInteger, IError>); override;
    class procedure WithdrawEx(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, BigInteger, IError>); override;
  end;

  TAaveLendingPool = class(TCustomContract)
  protected
    procedure GetReserveData(const reserve: TReserve; const callback: TProc<TTuple, IError>);
  public
    procedure Deposit(
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure CurrentLiquidityRate(const reserve: TReserve; const callback: TProc<BigInteger, IError>);
  end;

  TAaveProtocolDataProvider = class(TCustomContract)
    procedure GetReserveTokensAddresses(const reserve: TReserve; const callback: TProc<TTuple, IError>);
  end;

  TAaveLendingPoolAddressesProvider = class(TCustomContract)
  public
    constructor Create(const aClient: IWeb3); reintroduce;
    procedure GetLendingPool(const callback: TProc<TAddress, IError>);
    procedure GetAddress(const id: TBytes32; const callback: TProc<TAddress, IError>);
    procedure GetProtocolDataProvider(const callback: TProc<TAddress, IError>);
  end;

  TaToken = class(TERC20)
  public
    procedure UNDERLYING_ASSET_ADDRESS(const callback: TProc<TAddress, IError>);
  end;

implementation

{ TAave }

class procedure TAave.UNDERLYING_TO_TOKEN(
  const client  : IWeb3;
  const reserve : TReserve;
  const callback: TProc<TAddress, IError>);
begin
  const ap = TAaveLendingPoolAddressesProvider.Create(client);
  try
    ap.GetProtocolDataProvider(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(TAddress.Zero, err);
        EXIT;
      end;
      const dp = TAaveProtocolDataProvider.Create(client, addr);
      try
        dp.GetReserveTokensAddresses(reserve, procedure(tup: TTuple; err: IError)
        begin
          if Assigned(err) or (Length(tup) = 0) then
            callback(TAddress.Zero, err)
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
  const client  : IWeb3;
  const token   : TAddress;
  const callback: TProc<TAddress, IError>);
begin
  const erc20 = TaToken.Create(client, token);
  try
    erc20.UNDERLYING_ASSET_ADDRESS(callback);
  finally
    erc20.Free;
  end;
end;

class procedure TAave.Approve(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  const ap = TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(ap) then
  try
    ap.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
        callback(nil, err)
      else
        reserve.Address(client.chain)
          .ifErr(procedure(err: IError)
          begin
            callback(nil, err)
          end)
          .&else(procedure(underlying: TAddress)
          begin
            web3.eth.erc20.approve(web3.eth.erc20.create(client, underlying), from, pool, amount, callback)
          end);
    end);
  finally
    ap.Free;
  end;
end;

class function TAave.Name: string;
begin
  Result := 'Aave v2';
end;

class function TAave.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve in [DAI, USDC, USDT, TUSD]);
end;

class procedure TAave.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  const ap = TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(ap) then
  try
    ap.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      const lp = TAaveLendingPool.Create(client, pool);
      if Assigned(lp) then
      try
        lp.CurrentLiquidityRate(reserve, procedure(qty: BigInteger; err: IError)
        begin
          if Assigned(err) then
            callback(0, err)
          else
            callback(BigInteger.Divide(qty, BigInteger.Create(1e21)).AsInt64 / 1e4, nil);
        end);
      finally
        lp.Free;
      end;
    end);
  finally
    ap.Free;
  end;
end;

class procedure TAave.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  // Before supplying an asset, we must first approve the LendingPool contract.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const ap = TAaveLendingPoolAddressesProvider.Create(client);
    if Assigned(ap) then
    try
      ap.GetLendingPool(procedure(pool: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        const lp = TAaveLendingPool.Create(client, pool);
        if Assigned(lp) then
        try
          lp.Deposit(from, reserve, amount, callback);
        finally
          lp.Free;
        end;
      end);
    finally
      ap.Free;
    end;
  end);
end;

class procedure TAave.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  Self.UNDERLYING_TO_TOKEN(client, reserve, procedure(token: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      web3.eth.erc20.create(client, token).BalanceOf(owner, callback);
  end);
end;

class procedure TAave.Withdraw(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(owner: TAddress)
    begin
      Self.Balance(client, owner, reserve, procedure(amount: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          Self.WithdrawEx(client, from, reserve, amount, callback);
      end);
    end);
end;

class procedure TAave.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const ap = TAaveLendingPoolAddressesProvider.Create(client);
  if Assigned(ap) then
  try
    ap.GetLendingPool(procedure(pool: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, 0, err);
        EXIT;
      end;
      const lp = TAaveLendingPool.Create(client, pool);
      if Assigned(lp) then
      try
        lp.Withdraw(from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
        begin
          if Assigned(err) then
            callback(nil, 0, err)
          else
            callback(rcpt, amount, nil);
        end);
      finally
        lp.Free;
      end;
    end);
  finally
    ap.Free;
  end;
end;

{ TAaveLendingPool }

procedure TAaveLendingPool.Deposit(
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  reserve.Address(Client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      from.GetAddress
        .ifErr(procedure(err: IError)
        begin
          callback(nil, err)
        end)
        .&else(procedure(receiver: TAddress)
        begin
          web3.eth.write(Self.Client, from, Self.Contract, 'deposit(address,uint256,address,uint16)', [underlying, web3.utils.toHex(amount), receiver, 42], callback)
        end);
    end);
end;

procedure TAaveLendingPool.Withdraw(
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  reserve.Address(Client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      from.GetAddress
        .ifErr(procedure(err: IError)
        begin
          callback(nil, err)
        end)
        .&else(procedure(receiver: TAddress)
        begin
          web3.eth.write(Self.Client, from, Self.Contract, 'withdraw(address,uint256,address)', [underlying, web3.utils.toHex(amount), receiver], callback)
        end);
    end);
end;

procedure TAaveLendingPool.GetReserveData(const reserve: TReserve; const callback: TProc<TTuple, IError>);
begin
  reserve.Address(Client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      web3.eth.call(Client, Contract, 'getReserveData(address)', [underlying], callback)
    end);
end;

procedure TAaveLendingPool.CurrentLiquidityRate(const reserve: TReserve; const callback: TProc<BigInteger, IError>);
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

procedure TAaveProtocolDataProvider.GetReserveTokensAddresses(const reserve: TReserve; const callback: TProc<TTuple, IError>);
begin
  reserve.Address(Client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      web3.eth.call(Client, Contract, 'getReserveTokensAddresses(address)', [underlying], callback)
    end);
end;

{ TAaveLendingPoolAddressesProvider }

constructor TAaveLendingPoolAddressesProvider.Create(const aClient: IWeb3);
begin
  inherited Create(aClient, '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5');
end;

procedure TAaveLendingPoolAddressesProvider.GetLendingPool(const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'getLendingPool()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure TAaveLendingPoolAddressesProvider.GetAddress(const id: TBytes32; const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'getAddress(bytes32)', [web3.utils.toHex(bytes32ToByteArray(id))], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure TAaveLendingPoolAddressesProvider.GetProtocolDataProvider(const callback: TProc<TAddress, IError>);
const
  id: TBytes32 = (1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
begin
  Self.GetAddress(id, callback);
end;

{ TaToken }

procedure TaToken.UNDERLYING_ASSET_ADDRESS(const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'UNDERLYING_ASSET_ADDRESS()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

end.
