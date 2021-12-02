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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.defi,
  web3.eth.types,
  web3.eth.yearn.finance;

type
  TyEarnV2 = class(TyEarnCustom)
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client  : IWeb3;
      reserve : TReserve;
      period  : TPeriod;
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

implementation

type
  TyDAIv2 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyUSDCv2 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyUSDTv2 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyTUSDv2 = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

const
  yTokenClass: array[TReserve] of TyTokenClass = (
    TyDAIv2,  // DAI
    TyUSDCv2, // USDC
    TyUSDTv2, // USDT
    nil,      // mUSD
    TyTUSDv2  // TUSD
  );

{ TyEarnV2 }

class function TyEarnV2.Name: string;
begin
  Result := 'yEarn v2';
end;

class function TyEarnV2.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Mainnet) and (reserve in [DAI, USDC, USDT, TUSD]);
end;

class procedure TyEarnV2.APY(
  client  : IWeb3;
  reserve : TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);
begin
  Self._APY(client, yTokenClass[reserve], period, callback);
end;

class procedure TyEarnV2.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  Self._Deposit(client, from, yTokenClass[reserve], amount, callback);
end;

class procedure TyEarnV2.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  Self._Balance(client, owner, yTokenClass[reserve], callback);
end;

class procedure TyEarnV2.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  Self._Withdraw(client, from, yTokenClass[reserve], callback);
end;

class procedure TyEarnV2.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  Self._WithdrawEx(client, from, yTokenClass[reserve], amount, callback);
end;

{ TyDAIv2 }

class function TyDAIv2.DeployedAt: TAddress;
begin
  Result := TAddress('0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01');
end;

{ TyUSDCv2 }

class function TyUSDCv2.DeployedAt: TAddress;
begin
  Result := TAddress('0xd6aD7a6750A7593E092a9B218d66C0A814a3436e');
end;

{ TyUSDTv2 }

class function TyUSDTv2.DeployedAt: TAddress;
begin
  Result := TAddress('0x83f798e925BcD4017Eb265844FDDAbb448f1707D');
end;

{ TyTUSDv2 }

class function TyTUSDv2.DeployedAt: TAddress;
begin
  Result := TAddress('0x73a052500105205d34daf004eab301916da8190f');
end;

end.
