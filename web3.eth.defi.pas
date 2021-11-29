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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.erc20,
  web3.eth.types;

type
  TReserve = (DAI, USDC, USDT, MUSD, TUSD);

  TReserveHelper = record helper for TReserve
    function  Symbol  : string;
    function  Decimals: Double;
    function  Address : TAddress;
    function  Scale(amount: Double): BigInteger;
    function  Unscale(amount: BigInteger): Double;
    procedure BalanceOf(client: IWeb3; owner: TAddress; callback: TAsyncQuantity);
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
      chain  : TChain;
      reserve: TReserve): Boolean; virtual; abstract;
    // Returns the annual yield as a percentage with 4 decimals.
    class procedure APY(
      client  : IWeb3;
      reserve : TReserve;
      period  : TPeriod;
      callback: TAsyncFloat); virtual; abstract;
    // Deposits an underlying asset into the lending pool.
    class procedure Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); virtual; abstract;
    // Returns how much underlying assets you are entitled to.
    class procedure Balance(
      client  : IWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); virtual; abstract;
    // Withdraws your underlying asset from the lending pool.
    class procedure Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceiptEx); virtual; abstract;
    class procedure WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceiptEx); virtual; abstract;
  end;

  TLendingProtocolClass = class of TLendingProtocol;
  TAsyncLendingProtocol = reference to procedure(proto: TLendingProtocolClass; err: IError);

implementation

uses
  // Delphi
  System.TypInfo;

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
  case Self of
    DAI : Result := 1e18;
    USDC: Result := 1e6;
    USDT: Result := 1e6;
    MUSD: Result := 1e18;
    TUSD: Result := 1e18;
  else
    raise EWeb3.CreateFmt('%s not implemented', [Self.Symbol]);
  end;
end;

function TReserveHelper.Address: TAddress;
begin
  case Self of
    DAI : Result := '0x6b175474e89094c44da98b954eedeac495271d0f';
    USDC: Result := '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
    USDT: Result := '0xdac17f958d2ee523a2206206994597c13d831ec7';
    MUSD: Result := '0xe2f2a5C287993345a840Db3B0845fbC70f5935a5';
    TUSD: Result := '0x0000000000085d4780B73119b644AE5ecd22b376';
  else
    raise EWeb3.CreateFmt('%s not implemented', [Self.Symbol]);
  end;
end;

function TReserveHelper.Scale(amount: Double): BigInteger;
begin
  Result := BigInteger.Create(amount * Self.Decimals);
end;

function TReserveHelper.Unscale(amount: BigInteger): Double;
begin
  Result := amount.AsDouble / Self.Decimals;
end;

procedure TReserveHelper.BalanceOf(client: IWeb3; owner: TAddress; callback: TAsyncQuantity);
var
  erc20: TERC20;
begin
  erc20 := TERC20.Create(client, Self.Address);
  try
    erc20.BalanceOf(owner, callback);
  finally
    erc20.Free;
  end;
end;

end.
