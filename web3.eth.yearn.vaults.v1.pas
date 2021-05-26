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

unit web3.eth.yearn.vaults.v1;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.defi,
  web3.eth.types;

type
  TyVaultV1 = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    class procedure TokenToUnderlying(
      client  : TWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToToken(
      client  : TWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
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

uses
  // web3
  web3.eth.yearn.finance;

type
  TyDAI = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyUSDC = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyUSDT = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TyMUSD = class(TyToken)
  public
    class function DeployedAt: TAddress; override;
  end;

type
  TyTokenClass = class of TyToken;

const
  yTokenClass: array[TReserve] of TyTokenClass = (
    TyDAI,
    TyUSDC,
    TyUSDT,
    TyMUSD
  );

{ TyVaultV1 }

class procedure TyVaultV1.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  var yToken := yTokenClass[reserve].Create(client);
  if Assigned(yToken) then
  begin
    yToken.ApproveUnderlying(from, amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      try
        callback(rcpt, err);
      finally
        yToken.Free;
      end;
    end);
  end;
end;

class procedure TyVaultV1.TokenToUnderlying(
  client  : TWeb3;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncQuantity);
begin
  var yToken := yTokenClass[reserve].Create(client);
  if Assigned(yToken) then
  try
    yToken.TokenToUnderlying(amount, callback);
  finally
    yToken.Free;
  end;
end;

class procedure TyVaultV1.UnderlyingToToken(
  client  : TWeb3;
  reserve : TReserve;
  amount  : BIgInteger;
  callback: TAsyncQuantity);
begin
  var yToken := yTokenClass[reserve].Create(client);
  if Assigned(yToken) then
  try
    yToken.UnderlyingToToken(amount, callback);
  finally
    yToken.Free;
  end;
end;

class function TyVaultV1.Name: string;
begin
  Result := 'yVault v1';
end;

class function TyVaultV1.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Mainnet) and (Reserve in [DAI, USDC, USDT, mUSD]);
end;

class procedure TyVaultV1.APY(
  client  : TWeb3;
  reserve : TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);
begin
  var yToken := yTokenClass[reserve].Create(client);
  if Assigned(yToken) then
  begin
    yToken.APY(period, procedure(apy: Extended; err: IError)
    begin
      try
        callback(apy, err);
      finally
        yToken.Free;
      end;
    end);
  end;
end;

class procedure TyVaultV1.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var yToken := yTokenClass[reserve].Create(client);
    if Assigned(yToken) then
    try
      yToken.Deposit(from, amount, callback);
    finally
      yToken.Free;
    end;
  end);
end;

class procedure TyVaultV1.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  var yToken := yTokenClass[reserve].Create(client);
  if Assigned(yToken) then
  try
    // step #1: get the yToken balance
    yToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      // step #2: multiply it by the current yToken price
      TokenToUnderlying(client, reserve, balance, procedure(output: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(output, nil);
      end);
    end);
  finally
    yToken.Free;
  end;
end;

class procedure TyVaultV1.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  var yToken := yTokenClass[reserve].Create(client);
  if Assigned(yToken) then
  begin
    // step #1: get the yToken balance
    yToken.BalanceOf(from, procedure(balance: BigInteger; err: IError)
    begin
      try
        if Assigned(err) then
        begin
          callback(nil, 0, err);
          EXIT;
        end;
        // step #2: withdraw yToken-amount in exchange for the underlying asset.
        yToken.Withdraw(from, balance, procedure(rcpt: ITxReceipt; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          // step #3: from yToken-balance to Underlying-balance
          TokenToUnderlying(client, reserve, balance, procedure(output: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(rcpt, 0, err)
            else
              callback(rcpt, output, nil);
          end);
        end);
      finally
        yToken.Free;
      end;
    end);
  end;
end;

class procedure TyVaultV1.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  // step #1: from Underlying-amount to yToken-amount
  UnderlyingToToken(client, reserve, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    var yToken := yTokenClass[reserve].Create(client);
    if Assigned(yToken) then
    try
      // step #2: withdraw yToken-amount in exchange for the underlying asset.
      yToken.Withdraw(from, input, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          callback(rcpt, amount, nil);
      end);
    finally
      yToken.Free;
    end;
  end);
end;

{ TyDAI }

class function TyDAI.DeployedAt: TAddress;
begin
  Result := TAddress('0xACd43E627e64355f1861cEC6d3a6688B31a6F952');
end;

{ TyUSDC }

class function TyUSDC.DeployedAt: TAddress;
begin
  Result := TAddress('0x597aD1e0c13Bfe8025993D9e79C69E1c0233522e');
end;

{ TyUSDT }

class function TyUSDT.DeployedAt: TAddress;
begin
  Result := TAddress('0x2f08119C6f07c006695E079AAFc638b8789FAf18');
end;

{ TyMUSD }

class function TyMUSD.DeployedAt: TAddress;
begin
  Result := TAddress('0xE0db48B4F71752C4bEf16De1DBD042B82976b8C7');
end;

end.
