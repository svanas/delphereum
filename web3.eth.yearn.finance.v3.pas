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

unit web3.eth.yearn.finance.v3;

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
  TyEarnV3 = class(TyEarnCustom)
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

type
  TyDAIv3 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyUSDCv3 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyUSDTv3 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

const
  yTokenClass: array[TReserve] of TyTokenClass = (
    TyDAIv3,  // DAI
    TyUSDCv3, // USDC
    TyUSDTv3, // USDT
    nil,      // TUSD
    nil       // mUSD
  );

{ TyEarnV3 }

class function TyEarnV3.Name: string;
begin
  Result := 'yEarn v3';
end;

class function TyEarnV3.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve in [DAI, USDC, USDT]);
end;

class procedure TyEarnV3.APY(
  client   : IWeb3;
  etherscan: IEtherscan;
  reserve  : TReserve;
  period   : TPeriod;
  callback : TProc<Double, IError>);
begin
  Self._APY(client, etherscan, yTokenClass[reserve], period, callback);
end;

class procedure TyEarnV3.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  Self._Deposit(client, from, yTokenClass[reserve], amount, callback);
end;

class procedure TyEarnV3.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TProc<BigInteger, IError>);
begin
  Self._Balance(client, owner, yTokenClass[reserve], callback);
end;

class procedure TyEarnV3.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  Self._Withdraw(client, from, yTokenClass[reserve], callback);
end;

class procedure TyEarnV3.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  Self._WithdrawEx(client, from, yTokenClass[reserve], amount, callback);
end;

{ TyDAIv3 }

class function TyDAIv3.DeployedAt: TAddress;
begin
  Result := TAddress('0xC2cB1040220768554cf699b0d863A3cd4324ce32');
end;

{ TyUSDCv3 }

class function TyUSDCv3.DeployedAt: TAddress;
begin
  Result := TAddress('0x26EA744E5B887E5205727f55dFBE8685e3b21951');
end;

{ TyUSDTv2 }

class function TyUSDTv3.DeployedAt: TAddress;
begin
  Result := TAddress('0xE6354ed5bC4b393a5Aad09f21c46E101e692d447');
end;

end.
