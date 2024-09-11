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

unit web3.eth.defi;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.erc20,
  web3.eth.etherscan,
  web3.eth.types;

type
  TReserve = (DAI, USDC, USDT, TUSD);

  TReserveHelper = record helper for TReserve
    function  Symbol  : string;
    function  Decimals: Double;
    function  Address(const chain: TChain): IResult<TAddress>;
    function  Scale(const amount: Double): BigInteger;
    function  Unscale(const amount: BigInteger): Double;
    procedure BalanceOf(const client: IWeb3; const owner: TAddress; const callback: TProc<BigInteger, IError>);
  end;

  TPeriod = (oneDay, threeDays, oneWeek, twoWeeks, oneMonth);

  TPeriodHelper = record helper for TPeriod
    function Days   : Double;
    function Hours  : Double;
    function Minutes: Integer;
    function Seconds: Integer;
    function ToYear(value: Double): Double;
  end;

  TLendingProtocol = class abstract
  public
    class function Name: string; virtual; abstract;
    class function Supports(
      const chain  : TChain;
      const reserve: TReserve): Boolean; virtual; abstract;
    // Returns the annual yield as a percentage with 4 decimals.
    class procedure APY(
      const client   : IWeb3;
      const etherscan: IEtherscan;
      const reserve  : TReserve;
      const period   : TPeriod;
      const callback : TProc<Double, IError>); virtual; abstract;
    // Deposits an underlying asset into the lending pool.
    class procedure Deposit(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>); virtual; abstract;
    // Returns how much underlying assets you are entitled to.
    class procedure Balance(
      const client  : IWeb3;
      const owner   : TAddress;
      const reserve : TReserve;
      const callback: TProc<BigInteger, IError>); virtual; abstract;
    // Withdraws your underlying asset from the lending pool.
    class procedure Withdraw(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const callback: TProc<ITxReceipt, BigInteger, IError>); virtual; abstract;
    class procedure WithdrawEx(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, BigInteger, IError>); virtual; abstract;
  end;

  TLendingProtocolClass = class of TLendingProtocol;

implementation

uses
  // Delphi
  System.TypInfo,
  // web3
  web3.error,
  web3.eth;

{ TPeriodHelper }

function TPeriodHelper.Days: Double;
begin
  Result := 1;
  case Self of
    threeDays: Result := 3;
    oneWeek  : Result := 7;
    twoWeeks : Result := 14;
    oneMonth : Result := 365.25 / 12;
  end;
end;

function TPeriodHelper.Hours: Double;
begin
  Result := Self.Days * 24;
end;

function TPeriodHelper.Minutes: Integer;
begin
  Result := Round(Self.Hours * 60);
end;

function TPeriodHelper.Seconds: Integer;
begin
  Result := Self.Minutes * 60;
end;

function TPeriodHelper.ToYear(value: Double): Double;
begin
  Result := value * (365.25 / Self.Days);
end;

{ TReserveHelper }

function TReserveHelper.Symbol: string;
begin
  Result := GetEnumName(TypeInfo(TReserve), Ord(Self));
end;

function TReserveHelper.Decimals: Double;
begin
  if Self in [USDC, USDT] then
    Result := 1e6
  else
    Result := 1e18;
end;

function TReserveHelper.Address(const chain: TChain): IResult<TAddress>;
begin
  if chain <> Ethereum then
  begin
    Result := TResult<TAddress>.Err(TSilent.Create('%s not implemented on %s', [Self.Symbol, chain.Name]));
    EXIT;
  end;
  case Self of
    DAI : Result := TResult<TAddress>.Ok('0x6b175474e89094c44da98b954eedeac495271d0f');
    USDC: Result := TResult<TAddress>.Ok('0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48');
    USDT: Result := TResult<TAddress>.Ok('0xdac17f958d2ee523a2206206994597c13d831ec7');
    TUSD: Result := TResult<TAddress>.Ok('0x0000000000085d4780B73119b644AE5ecd22b376');
  else
    Result := TResult<TAddress>.Err(TSilent.Create('%s not implemented', [Self.Symbol]));
  end;
end;

function TReserveHelper.Scale(const amount: Double): BigInteger;
begin
  Result := BigInteger.Create(amount * Self.Decimals);
end;

function TReserveHelper.Unscale(const amount: BigInteger): Double;
begin
  Result := amount.AsDouble / Self.Decimals;
end;

procedure TReserveHelper.BalanceOf(const client: IWeb3; const owner: TAddress; const callback: TProc<BigInteger, IError>);
begin
  Self.Address(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      if Supports(err, ISilent) then
        callback(0, nil)
      else
        callback(0, err);
    end)
    .&else(procedure(address: TAddress)
    begin
      web3.eth.erc20.create(client, address).BalanceOf(owner, callback)
    end);
end;

end.
