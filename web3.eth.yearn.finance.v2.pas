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

unit web3.eth.yearn.finance.v2;

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
  TyEarnV2 = class(TCustomYearn)
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client   : IWeb3;
      etherscan: IEtherscan;
      reserve  : TReserve;
      period   : TPeriod;
      callback : TProc<Double, IError>); override;
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

implementation

function yDAIv2(client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01');
end;

function yUSDCv2(client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0xd6aD7a6750A7593E092a9B218d66C0A814a3436e');
end;

function yUSDTv2(client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0x83f798e925BcD4017Eb265844FDDAbb448f1707D');
end;

function yTUSDv2(client: IWeb3): IyToken;
begin
  Result := TyToken.Create(client, '0x73a052500105205d34daf004eab301916da8190f');
end;

function yToken(client: IWeb3; reserve: TReserve): IResult<IyToken>;
begin
  case reserve of
    DAI : Result := TResult<IyToken>.Ok(yDAIv2(client));
    USDC: Result := TResult<IyToken>.Ok(yUSDCv2(client));
    USDT: Result := TResult<IyToken>.Ok(yUSDTv2(client));
    TUSD: Result := TResult<IyToken>.Ok(yTUSDv2(client));
  else
    Result := TResult<IyToken>.Err(nil, TError.Create('%s not supported', [reserve.Symbol]));
  end;
end;

{ TyEarnV2 }

class function TyEarnV2.Name: string;
begin
  Result := 'yEarn v2';
end;

class function TyEarnV2.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve in [DAI, USDC, USDT, TUSD]);
end;

class procedure TyEarnV2.APY(
  client   : IWeb3;
  etherscan: IEtherscan;
  reserve  : TReserve;
  period   : TPeriod;
  callback : TProc<Double, IError>);
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

class procedure TyEarnV2.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
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

class procedure TyEarnV2.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TProc<BigInteger, IError>);
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

class procedure TyEarnV2.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TProc<ITxReceipt, BigInteger, IError>);
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

class procedure TyEarnV2.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, BigInteger, IError>);
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
