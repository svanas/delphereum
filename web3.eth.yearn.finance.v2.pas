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
      client  : TWeb3;
      reserve : TReserve;
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
      reserve : TReserve;
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

const
  yTokenClass: array[TReserve] of TyTokenClass = (
    TyDAIv2,  // DAI
    TyUSDCv2, // USDC
    TyUSDTv2  // USDT
  );

{ TyEarnV2 }

class function TyEarnV2.Name: string;
begin
  Result := 'yEarn v2';
end;

class function TyEarnV2.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := chain = Mainnet;
end;

class procedure TyEarnV2.APY(
  client  : TWeb3;
  reserve : TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);
begin
  Self._APY(client, yTokenClass[reserve], period, callback);
end;

class procedure TyEarnV2.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  Self._Deposit(client, from, yTokenClass[reserve], amount, callback);
end;

class procedure TyEarnV2.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  Self._Balance(client, owner, yTokenClass[reserve], callback);
end;

class procedure TyEarnV2.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  Self._Withdraw(client, from, yTokenClass[reserve], callback);
end;

class procedure TyEarnV2.WithdrawEx(
  client  : TWeb3;
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
  Result := TAddress.New('0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01');
end;

{ TyUSDCv2 }

class function TyUSDCv2.DeployedAt: TAddress;
begin
  Result := TAddress.New('0xd6aD7a6750A7593E092a9B218d66C0A814a3436e');
end;

{ TyUSDTv2 }

class function TyUSDTv2.DeployedAt: TAddress;
begin
  Result := TAddress.New('0x83f798e925BcD4017Eb265844FDDAbb448f1707D');
end;

end.
