{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.origin.dollar;

{$I web3.inc}

interface

uses
  // Delphi
  System.DateUtils,
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
  TOrigin = class(TLendingProtocol)
  protected
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

  TOriginVault = class(TCustomContract)
  public
    constructor Create(const aClient: IWeb3); reintroduce;
    class function DeployedAt: TAddress;
    procedure Mint(const from: TPrivateKey; const reserve: TReserve; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Redeem(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
  end;

  IOriginDollar = interface(IERC20)
    procedure RebasingCreditsPerToken(const block: string; const callback: TProc<BigInteger, IError>);
  end;

implementation

procedure getAPY(const ousd: IOriginDollar; const etherscan: IEtherscan; const period: TPeriod; const callback: TProc<Double, IError>);
begin
  ousd.RebasingCreditsPerToken(BLOCK_LATEST, procedure(curr: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      etherscan.getBlockNumberByTimestamp(web3.Now - period.Seconds, procedure(bn: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          ousd.RebasingCreditsPerToken(web3.utils.toHex(bn), procedure(past: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(period.ToYear((1 / curr.AsDouble) / (1 / past.AsDouble) - 1) * 100, nil);
          end);
      end);
  end);
end;

{ TOriginDollar }

type
  TOriginDollar = class(TERC20, IOriginDollar)
  public
    constructor Create(const aClient: IWeb3); reintroduce;
    class function DeployedAt: TAddress;
    procedure RebasingCreditsPerToken(const block: string; const callback: TProc<BigInteger, IError>);
  end;

constructor TOriginDollar.Create(const aClient: IWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

class function TOriginDollar.DeployedAt: TAddress;
begin
  Result := '0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86';
end;

procedure TOriginDollar.RebasingCreditsPerToken(const block: string; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'rebasingCreditsPerToken()', block, [], callback);
end;

{ TOrigin }

class procedure TOrigin.Approve(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  reserve.Address(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      web3.eth.erc20.approve(web3.eth.erc20.create(client, underlying), from, TOriginVault.DeployedAt, amount, callback)
    end);
end;

class function TOrigin.Name: string;
begin
  Result := 'Origin';
end;

class function TOrigin.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve = USDC);
end;

class procedure TOrigin.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  getAPY(TOriginDollar.Create(client), etherscan, period, callback);
end;

class procedure TOrigin.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  Self.Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const vault = TOriginVault.Create(client);
    try
      vault.Mint(from, reserve, amount, callback);
    finally
      vault.Free;
    end;
  end);
end;

class procedure TOrigin.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  web3.eth.erc20.create(client, TOriginDollar.DeployedAt).BalanceOf(owner, procedure(balance: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(balance, err)
    else
      if reserve.Decimals = 1e18 then
        callback(balance, err)
      else
        callback(reserve.Scale(balance.AsDouble / 1e18), err);
  end);
end;

class procedure TOrigin.Withdraw(
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
      web3.eth.erc20.create(client, TOriginDollar.DeployedAt).BalanceOf(owner, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          Self.WithdrawEx(client, from, reserve, balance, callback);
      end);
    end);
end;

class procedure TOrigin.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const vault = TOriginVault.Create(client);
  try
    vault.Redeem(from, amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        callback(rcpt, amount, err);
    end);
  finally
    vault.Free;
  end;
end;

{ TOriginVault }

constructor TOriginVault.Create(const aClient: IWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

class function TOriginVault.DeployedAt: TAddress;
begin
  Result := '0xe75d77b1865ae93c7eaa3040b038d7aa7bc02f70';
end;

procedure TOriginVault.Mint(const from: TPrivateKey; const reserve: TReserve; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  reserve.Address(Client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'mint(address,uint256,uint256)', [underlying, web3.utils.toHex(amount), 0], callback)
    end);
end;

procedure TOriginVault.Redeem(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'redeem(uint256,uint256)', [web3.utils.toHex(amount), 0], callback);
end;

end.
