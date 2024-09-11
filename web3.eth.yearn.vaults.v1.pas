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

unit web3.eth.yearn.vaults.v1;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.defi,
  web3.eth.etherscan,
  web3.eth.types,
  web3.eth.yearn.finance;

type
  TyVaultV1 = class(TCustomYearn)
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

implementation

function yDAI(const client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0xACd43E627e64355f1861cEC6d3a6688B31a6F952');
end;

function yUSDC(const client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e');
end;

function yUSDT(const client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0x2f08119C6f07c006695E079AAFc638b8789FAf18');
end;

function yTUSD(const client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0x37d19d1c4E1fa9DC47bD1eA12f742a0887eDa74a');
end;

function yToken(const client: IWeb3; const reserve: TReserve): IResult<IyToken>;
begin
  case reserve of
    DAI : Result := TResult<IyToken>.Ok(yDAI(client));
    USDC: Result := TResult<IyToken>.Ok(yUSDC(client));
    USDT: Result := TResult<IyToken>.Ok(yUSDT(client));
    TUSD: Result := TResult<IyToken>.Ok(yTUSD(client));
  else
    Result := TResult<IyToken>.Err(TError.Create('%s not supported', [reserve.Symbol]));
  end;
end;

{ TyVaultV1 }

class function TyVaultV1.Name: string;
begin
  Result := 'yVault v1';
end;

class function TyVaultV1.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (Reserve in [DAI, USDC, USDT, TUSD]);
end;

class procedure TyVaultV1.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  yToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(yToken: IyToken)
    begin
      Self.yAPY(yToken, etherscan, period, callback)
    end);
end;

class procedure TyVaultV1.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  yToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(yToken: IyToken)
    begin
      Self.yDeposit(client, yToken, from, amount, callback)
    end);
end;

class procedure TyVaultV1.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  yToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(yToken: IyToken)
    begin
      Self.yBalance(yToken, owner, callback)
    end);
end;

class procedure TyVaultV1.Withdraw(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  yToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(yToken: IyToken)
    begin
      Self.yWithdraw(yToken, from, callback)
    end);
end;

class procedure TyVaultV1.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  yToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(yToken: IyToken)
    begin
      Self.yWithdraw(yToken, from, amount, callback)
    end);
end;

end.
