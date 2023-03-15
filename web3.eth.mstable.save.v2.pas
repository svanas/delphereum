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

unit web3.eth.mstable.save.v2;

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
  web3.error,
  web3.eth,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.etherscan,
  web3.eth.types,
  web3.utils;

type
  TmStable = class(TLendingProtocol)
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

type
  IimUSD = interface(IERC20)
    procedure BalanceOfUnderlying(const owner: TAddress; const callback: TProc<BigInteger, IError>);
    procedure ExchangeRate(const block: string; const callback: TProc<BigInteger, IError>);
    procedure CreditsToUnderlying(const credits: BigInteger; const callback: TProc<BigInteger, IError>);
  end;

type
  TimVaultUSD = class(TCustomContract)
  public
    constructor Create(const aClient: IWeb3); reintroduce;
    procedure BalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
  end;

implementation

procedure getAPY(const imUSD: IimUSD; const etherscan: IEtherscan; const period: TPeriod; const callback: TProc<Double, IError>);
begin
  imUSD.ExchangeRate(BLOCK_LATEST, procedure(curr: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      etherscan.getBlockNumberByTimestamp(web3.Now - period.Seconds, procedure(bn: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          imUSD.ExchangeRate(web3.utils.toHex(bn), procedure(past: BigInteger; err: IError)
          begin
            if Assigned(err) then
               callback(0, err)
            else
              callback(period.ToYear(curr.AsDouble / past.AsDouble - 1) * 100, nil);
          end);
      end);
  end);
end;

{ TimUSD }

type
  TimUSD = class(TERC20, IimUSD)
  public
    constructor Create(const aClient: IWeb3); reintroduce;
    procedure BalanceOfUnderlying(const owner: TAddress; const callback: TProc<BigInteger, IError>);
    procedure ExchangeRate(const block: string; const callback: TProc<BigInteger, IError>);
    procedure CreditsToUnderlying(const credits: BigInteger; const callback: TProc<BigInteger, IError>);
  end;

constructor TimUSD.Create(const aClient: IWeb3);
begin
  inherited Create(aClient, '0x30647a72dc82d7fbb1123ea74716ab8a317eac19');
end;

procedure TimUSD.BalanceOfUnderlying(const owner: TAddress; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'balanceOfUnderlying(address)', [owner], callback);
end;

procedure TimUSD.ExchangeRate(const block: string; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'exchangeRate()', block, [], callback);
end;

procedure TimUSD.CreditsToUnderlying(const credits: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'creditsToUnderlying(uint256)', [web3.utils.toHex(credits)], callback);
end;

{ TmStable }

class function TmStable.Name: string;
begin
  Result := 'mStable';
end;

class function TmStable.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve = mUSD);
end;

class procedure TmStable.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  getAPY(TimUSD.Create(client), etherscan, period, callback);
end;

class procedure TmStable.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  callback(nil, TNotImplemented.Create);
end;

class procedure TmStable.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  const imUSD: IimUSD = TimUSD.Create(client);
  imUSD.BalanceOfUnderlying(owner, procedure(balance1: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    const vault = TImVaultUSD.Create(client);
    try
      vault.BalanceOf(owner, procedure(qty: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          imUSD.CreditsToUnderlying(qty, procedure(balance2: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(balance1 + balance2, nil);
          end);
      end);
    finally
      vault.Free;
    end;
  end);
end;

class procedure TmStable.Withdraw(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  callback(nil, 0, TNotImplemented.Create);
end;

class procedure TmStable.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  callback(nil, 0, TNotImplemented.Create);
end;

{ TimVaultUSD }

constructor TimVaultUSD.Create(const aClient: IWeb3);
begin
  inherited Create(aClient, '0x78BefCa7de27d07DC6e71da295Cc2946681A6c7B');
end;

procedure TimVaultUSD.BalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'balanceOf(address)', [owner], callback);
end;

end.
