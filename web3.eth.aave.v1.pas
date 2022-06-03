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
{            need tokens to test with?                                         }
{            1. make sure your wallet is set to the relevant testnet           }
{            2. go to https://testnet.aave.com/faucet                          }
{                                                                              }
{******************************************************************************}

unit web3.eth.aave.v1;

{$I web3.inc}

interface

uses
  // Delphi
  System.TypInfo,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types,
  web3.utils;

type
  EAave = class(EWeb3);

  // Global helper functions
  TAave = class(TLendingProtocol)
  protected
    class procedure UNDERLYING_ADDRESS(
      chain   : TChain;
      reserve : TReserve;
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

  // Global addresses register of the protocol. This contract is immutable and the address will never change.
  TAaveAddressesProvider = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure GetLendingPool(callback: TAsyncAddress);
    procedure GetLendingPoolCore(callback: TAsyncAddress);
  end;

  // The LendingPool contract is the main contract of the Aave protocol.
  TAaveLendingPool = class(TCustomContract)
  protected
    procedure GetReserveData(reserve: TReserve; callback: TAsyncTuple);
  public
    procedure Deposit(
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    procedure LiquidityRate(reserve: TReserve; callback: TAsyncQuantity);
    procedure aTokenAddress(reserve: TReserve; callback: TAsyncAddress);
  end;

  // aTokens are interest-bearing derivative tokens that are minted and burned
  // upon deposit (called from LendingPool) and redeem (called from the aToken contract).
  // If you are developing on a testnet and require tokens, go to
  // https://testnet.aave.com/faucet, making sure that your wallet is set to the relevant testnet.
  TaToken = class(TERC20)
  public
    procedure Redeem(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
  end;

// For internal calculations and to reduce the impact of rounding errors, the
// Aave protocol uses the concept of Ray Math. A Ray is a unit with 27 decimals
// of precision. All the rates (liquidity/borrow/utilisation rates) as well as
// the cumulative indexes and the aTokens exchange rates are expressed in Ray.
const
  RAY = 1e27;

implementation

{ TAave }

// Returns the ERC-20 contract address of the underlying asset.
class procedure TAave.UNDERLYING_ADDRESS(chain: TChain; reserve: TReserve; callback: TAsyncAddress);
begin
  if chain = Ethereum then
  begin
    reserve.Address(chain, callback);
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
  if (chain = Ropsten) and (reserve in [DAI, USDC, USDT]) then
  begin
    case reserve of
      DAI : callback('0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108', nil);
      USDC: callback('0x851dEf71f0e6A903375C1e536Bd9ff1684BAD802', nil);
      USDT: callback('0xB404c51BBC10dcBE948077F18a4B8E553D160084', nil);
    end;
    EXIT;
  end;
  callback(EMPTY_ADDRESS,
    TError.Create('%s is not supported on %s', [
      GetEnumName(TypeInfo(TReserve), Ord(reserve)), GetEnumName(TypeInfo(TChain), Ord(chain))
    ])
  );
end;

// Approve the LendingPoolCore contract to move your asset.
class procedure TAave.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  const aap = TAaveAddressesProvider.Create(client);
  if Assigned(aap) then
  try
    aap.GetLendingPoolCore(procedure(core: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      UNDERLYING_ADDRESS(client.Chain, reserve, procedure(addr: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        const erc20 = TERC20.Create(client, addr);
        if Assigned(erc20) then
        begin
          erc20.ApproveEx(from, core, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            try
              callback(rcpt, err);
            finally
              erc20.Free;
            end;
          end);
        end;
      end);
    end);
  finally
    aap.Free;
  end;
end;

class function TAave.Name: string;
begin
  Result := 'Aave';
end;

class function TAave.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain in [Ethereum, Ropsten, Kovan]) and (reserve in [DAI, USDC, USDT]);
end;

// Returns the annual yield as a percentage with 4 decimals.
class procedure TAave.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TAsyncFloat);
begin
  const aap = TAaveAddressesProvider.Create(client);
  if Assigned(aap) then
  try
    aap.GetLendingPool(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      const pool = TAaveLendingPool.Create(client, addr);
      if Assigned(pool) then
      try
        pool.LiquidityRate(reserve, procedure(qty: BigInteger; err: IError)
        begin
          if Assigned(err) then
            callback(0, err)
          else
            callback(BigInteger.Divide(qty, BigInteger.Create(1e21)).AsInt64 / 1e4, nil);
        end);
      finally
        pool.Free;
      end;
    end);
  finally
    aap.Free;
  end;
end;

// Global helper function that deposits an underlying asset into the reserve.
class procedure TAave.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  // Before supplying an asset, we must first approve the LendingPoolCore contract.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const aap = TAaveAddressesProvider.Create(client);
    if Assigned(aap) then
    try
      aap.GetLendingPool(procedure(addr: TAddress; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        const pool = TAaveLendingPool.Create(client, addr);
        if Assigned(pool) then
        try
          pool.Deposit(from, reserve, amount, callback);
        finally
          pool.Free;
        end;
      end);
    finally
      aap.Free;
    end;
  end);
end;

// Returns how much underlying assets you are entitled to.
class procedure TAave.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  const aAp = TAaveAddressesProvider.Create(client);
  if Assigned(aAp) then
  try
    aAp.GetLendingPool(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      const aPool = TAaveLendingPool.Create(client, addr);
      if Assigned(aPool) then
      try
        aPool.aTokenAddress(reserve, procedure(addr: TAddress; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(0, err);
            EXIT;
          end;
          const aToken = TaToken.Create(client, addr);
          if Assigned(aToken) then
          try
            aToken.BalanceOf(owner, callback);
          finally
            aToken.Free;
          end;
        end);
      finally
        aPool.Free;
      end;
    end);
  finally
    aAp.Free;
  end;
end;

// Global helper function that redeems your balance of aTokens for the underlying asset.
class procedure TAave.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    Balance(client, addr, reserve, procedure(amount: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        WithdrawEx(client, from, reserve, amount, callback);
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
  const aAp = TAaveAddressesProvider.Create(client);
  if Assigned(aAp) then
  try
    aAp.GetLendingPool(procedure(addr: TAddress; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, 0, err);
        EXIT;
      end;
      const aPool = TAaveLendingPool.Create(client, addr);
      if Assigned(aPool) then
      try
        aPool.aTokenAddress(reserve, procedure(addr: TAddress; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          const aToken = TaToken.Create(client, addr);
          if Assigned(aToken) then
          try
            if Assigned(err) then
            begin
              callback(nil, 0, err);
              EXIT;
            end;
            aToken.Redeem(from, amount, procedure(rcpt: ITxReceipt; err: IError)
            begin
              if Assigned(err) then
                callback(nil, 0, err)
              else
                callback(rcpt, amount, nil);
            end);
          finally
            aToken.Free;
          end;
        end);
      finally
        aPool.Free;
      end;
    end);
  finally
    aAp.Free;
  end;
end;

{ TAaveAddressesProvider }

constructor TAaveAddressesProvider.Create(aClient: IWeb3);
begin
  // https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
  if aClient.Chain = Ethereum then
    inherited Create(aClient, '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8')
  else
    if aClient.Chain = Kovan then
      inherited Create(aClient, '0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5')
    else
      if aClient.Chain = Ropsten then
        inherited Create(aClient, '0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728')
      else
        raise EAave.CreateFmt('Aave is not deployed on %s', [GetEnumName(TypeInfo(TChain), Integer(aClient.Chain))]);
end;

// Fetch the address of the latest implementation of the LendingPool contract.
// Note: this is the address then you will need to create TAaveLendingPool with.
procedure TAaveAddressesProvider.GetLendingPool(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'getLendingPool()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

// Fetch the address of the latest implementation of the LendingPoolCore contract.
// Note: this is the address that you should approve() of `amount` before you deposit into the LendingPool.
procedure TAaveAddressesProvider.GetLendingPoolCore(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'getLendingPoolCore()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

{ TAaveLendingPool }

// Deposits the underlying asset into the reserve. A corresponding amount of the overlying asset (aTokens) is minted.
// The amount of aTokens received depends on the corresponding aToken exchange rate.
// When depositing an ERC-20 token, the LendingPoolCore contract (which is different from the LendingPool contract)
// will need to have the relevant allowance via approve() of `amount` for the underlying ERC20 of the `reserve` asset
// you are depositing.
procedure TAaveLendingPool.Deposit(
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  TAave.UNDERLYING_ADDRESS(Client.Chain, reserve, procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(
        Client, from, Contract,
        'deposit(address,uint256,uint16)',
        [addr, web3.utils.toHex(amount), 42], callback);
  end);
end;

// https://docs.aave.com/developers/developing-on-aave/the-protocol/lendingpool#getreservedata
procedure TAaveLendingPool.GetReserveData(reserve: TReserve; callback: TAsyncTuple);
begin
  TAave.UNDERLYING_ADDRESS(Client.Chain, reserve, procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.call(Client, Contract, 'getReserveData(address)', [addr], callback);
  end);
end;

// Returns current yearly interest (APY) earned by the depositors, in Ray units.
procedure TAaveLendingPool.LiquidityRate(reserve: TReserve; callback: TAsyncQuantity);
begin
  GetReserveData(reserve, procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(tup[4].toBigInt, nil);
  end);
end;

// Returns aToken contract address for the specified reserve.
// Note: this is the address then you will need to create TaToken with.
procedure TAaveLendingPool.aTokenAddress(reserve: TReserve; callback: TAsyncAddress);
begin
  GetReserveData(reserve, procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(tup[11].toAddress, nil);
  end);
end;

{ TaToken }

// redeem an `amount` of aTokens for the underlying asset, burning the aTokens during the process.
procedure TaToken.Redeem(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(
    Client, from, Contract,
    'redeem(uint256)', [web3.utils.toHex(amount)], callback);
end;

end.
