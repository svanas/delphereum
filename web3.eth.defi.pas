{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
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
  TReserve = (DAI, USDC, USDT);

  TReserveHelper = record helper for TReserve
    function  Symbol  : string;
    function  Decimals: Extended;
    function  Address : TAddress;
    function  Scale(amount: Extended): BigInteger;
    function  Unscale(amount: BigInteger): Extended;
    procedure BalanceOf(client: TWeb3; owner: TAddress; callback: TAsyncQuantity);
  end;

  TPeriod = (oneDay, threeDays, oneWeek, oneMonth);

  TPeriodHelper = record helper for TPeriod
    function Days   : Extended;
    function Hours  : Extended;
    function Minutes: Integer;
    function Seconds: Integer;
    function ToYear(value: Extended): Extended;
  end;

  TLendingProtocol = class abstract
  public
    class function Name: string; virtual; abstract;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; virtual; abstract;
    // Returns the annual yield as a percentage with 4 decimals.
    class procedure APY(
      client  : TWeb3;
      reserve : TReserve;
      period  : TPeriod;
      callback: TAsyncFloat); virtual; abstract;
    // Deposits an underlying asset into the lending pool.
    class procedure Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); virtual; abstract;
    // Returns how much underlying assets you are entitled to.
    class procedure Balance(
      client  : TWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); virtual; abstract;
    // Withdraws your underlying asset from the lending pool.
    class procedure Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceiptEx); virtual; abstract;
    class procedure WithdrawEx(
      client  : TWeb3;
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

function TPeriodHelper.Days: Extended;
begin
  Result := 1;
  case Self of
    threeDays: Result := 3;
    oneWeek  : Result := 7;
    oneMonth : Result := 365.25 / 12;
  end;
end;

function TPeriodHelper.Hours: Extended;
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

function TPeriodHelper.ToYear(value: Extended): Extended;
begin
  Result := value * (365.25 / Self.Days);
end;

{ TReserveHelper }

function TReserveHelper.Symbol: string;
begin
  Result := GetEnumName(TypeInfo(TReserve), Ord(Self));
end;

function TReserveHelper.Decimals: Extended;
begin
  case Self of
    DAI : Result := 1e18;
    USDC: Result := 1e6;
    USDT: Result := 1e6;
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
  else
    raise EWeb3.CreateFmt('%s not implemented', [Self.Symbol]);
  end;
end;

function TReserveHelper.Scale(amount: Extended): BigInteger;
begin
  Result := BigInteger.Create(amount * Self.Decimals);
end;

function TReserveHelper.Unscale(amount: BigInteger): Extended;
begin
  Result := amount.AsExtended / Self.Decimals;
end;

procedure TReserveHelper.BalanceOf(client: TWeb3; owner: TAddress; callback: TAsyncQuantity);
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
