{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.mstable.save.v2;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types;

type
  TmStable = class(TLendingProtocol)
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client  : TWeb3;
      _reserve: TReserve;
      period  : TPeriod;
      callback: TAsyncFloat); override;
    class procedure Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); override;
    class procedure Balance(
      client  : TWeb3;
      owner   : TAddress;
      _reserve: TReserve;
      callback: TAsyncQuantity); override;
    class procedure Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceiptEx); override;
    class procedure WithdrawEx(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceiptEx); override;
  end;

type
  TimUSD = class(TERC20)
  public
    constructor Create(aClient: TWeb3); reintroduce;
    procedure APY(period: TPeriod; callback: TAsyncFloat);
    procedure BalanceOfUnderlying(owner: TAddress; callback: TAsyncQuantity);
    procedure ExchangeRate(const block: string; callback: TAsyncQuantity);
  end;

implementation

uses
  // web3
  web3.eth,
  web3.eth.etherscan,
  web3.utils;

{ TmStable }

class function TmStable.Name: string;
begin
  Result := 'mStable';
end;

class function TmStable.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Mainnet) and (reserve = mUSD);
end;

class procedure TmStable.APY(
  client  : TWeb3;
  _reserve: TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);
begin
  var imUSD := TimUSD.Create(client);
  if Assigned(imUSD) then
  begin
    imUSD.APY(period, procedure(apy: Extended; err: IError)
    begin
      try
        callback(apy, err);
      finally
        imUSD.Free;
      end;
    end);
  end;
end;

class procedure TmStable.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  callback(nil, TNotImplemented.Create);
end;

class procedure TmStable.Balance(
  client  : TWeb3;
  owner   : TAddress;
  _reserve: TReserve;
  callback: TAsyncQuantity);
begin
  var imUSD := TimUSD.Create(client);
  try
    imUSD.BalanceOfUnderlying(owner, callback);
  finally
    imUSD.Free;
  end;
end;

class procedure TmStable.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  callback(nil, 0, TNotImplemented.Create);
end;

class procedure TmStable.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  callback(nil, 0, TNotImplemented.Create);
end;

{ TimUSD }

constructor TimUSD.Create(aClient: TWeb3);
begin
  inherited Create(aClient, '0x30647a72dc82d7fbb1123ea74716ab8a317eac19');
end;

procedure TimUSD.APY(period: TPeriod; callback: TAsyncFloat);
begin
  Self.ExchangeRate(BLOCK_LATEST, procedure(curr: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    getBlockNumberByTimestamp(client, web3.Now - period.Seconds, procedure(bn: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      Self.ExchangeRate(web3.utils.toHex(bn), procedure(past: BigInteger; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(0, err);
          EXIT;
        end;
        callback(period.ToYear(curr.AsExtended / past.AsExtended - 1) * 100, nil);
      end);
    end);
  end);
end;

procedure TimUSD.BalanceOfUnderlying(owner: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'balanceOfUnderlying(address)', [owner], callback);
end;

procedure TimUSD.ExchangeRate(const block: string; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'exchangeRate()', block, [], callback);
end;

end.
