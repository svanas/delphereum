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

unit web3.eth.yearn.finance;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.etherscan,
  web3.eth.types,
  web3.utils;

type
  TyTokenClass = class of TyToken;

  TyEarnCustom = class abstract(TLendingProtocol)
  strict private
    class procedure Approve(
      client  : TWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    class procedure BalanceOf(
      client  : TWeb3;
      yToken  : TyTokenClass;
      owner   : TAddress;
      callback: TAsyncQuantity);
    class procedure TokenToUnderlying(
      client  : TWeb3;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToToken(
      client  : TWeb3;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TAsyncQuantity);
  strict protected
    class procedure _APY(
      client  : TWeb3;
      yToken  : TyTokenClass;
      period  : TPeriod;
      callback: TAsyncFloat);
    class procedure _Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    class procedure _Balance(
      client  : TWeb3;
      owner   : TAddress;
      yToken  : TyTokenClass;
      callback: TAsyncQuantity);
    class procedure _Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      callback: TAsyncReceiptEx);
    class procedure _WithdrawEx(
      client  : TWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TAsyncReceiptEx);
  end;

  TyToken = class abstract(TERC20)
  public
    constructor Create(aClient: TWeb3); reintroduce;
    //------- read from contract -----------------------------------------------
    procedure Token(callback: TAsyncAddress);
    procedure GetPricePerFullShare(const block: string; callback: TAsyncQuantity);
    //------- helpers ----------------------------------------------------------
    class function DeployedAt: TAddress; virtual; abstract;
    procedure ApproveUnderlying(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure TokenToUnderlying(amount: BigInteger; callback: TAsyncQuantity);
    procedure UnderlyingToToken(amount: BigInteger; callback: TAsyncQuantity);
    procedure APY(period: TPeriod; callback: TAsyncFloat);
    //------- write to contract ------------------------------------------------
    procedure Deposit(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure Withdraw(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
  end;

implementation

uses
  // Delphi
  System.SysUtils;

{ TyEarnCustom }

class procedure TyEarnCustom.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  token: TyToken;
begin
  token := yToken.Create(client);
  if Assigned(token) then
  begin
    token.ApproveUnderlying(from, amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      try
        callback(rcpt, err);
      finally
        token.Free;
      end;
    end);
  end;
end;

class procedure TyEarnCustom.BalanceOf(
  client  : TWeb3;
  yToken  : TyTokenClass;
  owner   : TAddress;
  callback: TAsyncQuantity);
var
  token: TyToken;
begin
  token := yToken.Create(client);
  try
    token.BalanceOf(owner, callback);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom.TokenToUnderlying(
  client  : TWeb3;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TAsyncQuantity);
var
  token: TyToken;
begin
  token := yToken.Create(client);
  try
    token.TokenToUnderlying(amount, callback);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom.UnderlyingToToken(
  client  : TWeb3;
  yToken  : TyTokenClass;
  amount  : BIgInteger;
  callback: TAsyncQuantity);
var
  token: TyToken;
begin
  token := yToken.Create(client);
  try
    token.UnderlyingToToken(amount, callback);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom._APY(
  client  : TWeb3;
  yToken  : TyTokenClass;
  period  : TPeriod;
  callback: TAsyncFloat);
var
  token: TyToken;
begin
  token := yToken.Create(client);
  if Assigned(token) then
  begin
    token.APY(period, procedure(apy: Extended; err: IError)
    begin
      try
        callback(apy, err);
      finally
        token.Free;
      end;
    end);
  end;
end;

class procedure TyEarnCustom._Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  token: TyToken;
begin
  Self.Approve(client, from, yToken, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    token := yToken.Create(client);
    try
      token.Deposit(from, amount, callback);
    finally
      token.Free;
    end;
  end);
end;

class procedure TyEarnCustom._Balance(
  client  : TWeb3;
  owner   : TAddress;
  yToken  : TyTokenClass;
  callback: TAsyncQuantity);
var
  token: TyToken;
begin
  token := yToken.Create(client);
  try
    // step #1: get the yToken balance
    token.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        // step #2: multiply it by the current yToken price
        Self.TokenToUnderlying(client, yToken, balance, procedure(output: BigInteger; err: IError)
        begin
          if Assigned(err) then
            callback(0, err)
          else
            callback(output, nil);
        end);
    end);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom._Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  callback: TAsyncReceiptEx);
var
  token: TyToken;
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    // step #1: get the yToken balance
    Self.BalanceOf(client, yToken, addr, procedure(balance: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        if balance = 0 then
          callback(nil, 0, nil)
        else
        begin
          token := yToken.Create(client);
          try
            // step #2: withdraw yToken-amount in exchange for the underlying asset.
            token.Withdraw(from, balance, procedure(rcpt: ITxReceipt; err: IError)
            begin
              if Assigned(err) then
                callback(nil, 0, err)
              else
                // step #3: from yToken-balance to Underlying-balance
                Self.TokenToUnderlying(client, yToken, balance, procedure(output: BigInteger; err: IError)
                begin
                  if Assigned(err) then
                    callback(rcpt, 0, err)
                  else
                    callback(rcpt, output, nil);
                end);
            end);
          finally
            token.Free;
          end;
        end;
    end);
  end);
end;

class procedure TyEarnCustom._WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
var
  token: TyToken;
begin
  // step #1: from Underlying-amount to yToken-amount
  Self.UnderlyingToToken(client, yToken, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    token := yToken.Create(client);
    try
      // step #2: withdraw yToken-amount in exchange for the underlying asset.
      token.Withdraw(from, input, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          callback(rcpt, amount, nil);
      end);
    finally
      token.Free;
    end;
  end);
end;

{ TyToken }

constructor TyToken.Create(aClient: TWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

// Returns the underlying asset contract address for this yToken.
procedure TyToken.Token(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'token()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TAddress.New(hex), nil)
  end);
end;

// Current yToken price, in underlying (eg. DAI) terms.
procedure TyToken.GetPricePerFullShare(const block: string; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'getPricePerFullShare()', block, [], callback);
end;

procedure TyToken.ApproveUnderlying(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
var
  erc20: TERC20;
begin
  Self.Token(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    erc20 := TERC20.Create(client, addr);
    if Assigned(erc20) then
    begin
      erc20.ApproveEx(from, Self.Contract, amount, procedure(rcpt: ITxReceipt; err: IError)
      begin
        try
          callback(rcpt, err);
        finally
          erc20.Free;
        end;
      end);
    end;
  end);
end;

procedure TyToken.TokenToUnderlying(amount: BigInteger; callback: TAsyncQuantity);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsExtended * (price.AsExtended / 1e18)), nil);
  end);
end;

procedure TyToken.UnderlyingToToken(amount: BIgInteger; callback: TAsyncQuantity);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsExtended / (price.AsExtended / 1e18)), nil);
  end);
end;

procedure TyToken.APY(period: TPeriod; callback: TAsyncFloat);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(currPrice: BigInteger; err: IError)
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
      Self.GetPricePerFullShare(web3.utils.toHex(bn), procedure(pastPrice: BigInteger; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(0, err);
          EXIT;
        end;
        callback(((currPrice.AsExtended / pastPrice.AsExtended - 1) * 100) * (365 / period.Days), nil);
      end);
    end);
  end);
end;

procedure TyToken.Deposit(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract, 'deposit(uint256)', [web3.utils.toHex(amount)], callback);
end;

procedure TyToken.Withdraw(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract, 'withdraw(uint256)', [web3.utils.toHex(amount)], callback);
end;

end.
