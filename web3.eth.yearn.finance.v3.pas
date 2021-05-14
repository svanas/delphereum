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

unit web3.eth.yearn.finance.v3;

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
  TyEarnV3 = class(TyEarnCustom)
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
    nil       // mUSD
  );

{ TyEarnV3 }

class function TyEarnV3.Name: string;
begin
  Result := 'yEarn v3';
end;

class function TyEarnV3.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Mainnet) and (reserve in [DAI, USDC, USDT]);
end;

class procedure TyEarnV3.APY(
  client  : TWeb3;
  reserve : TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);
begin
  Self._APY(client, yTokenClass[reserve], period, callback);
end;

class procedure TyEarnV3.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  Self._Deposit(client, from, yTokenClass[reserve], amount, callback);
end;

class procedure TyEarnV3.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  Self._Balance(client, owner, yTokenClass[reserve], callback);
end;

class procedure TyEarnV3.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  Self._Withdraw(client, from, yTokenClass[reserve], callback);
end;

class procedure TyEarnV3.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
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
