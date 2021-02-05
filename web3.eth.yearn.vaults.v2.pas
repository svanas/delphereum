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

unit web3.eth.yearn.vaults.v2;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types;

type
  TyVaultV2 = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    class procedure TokenToUnderlyingAmount(
      client  : TWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToTokenAmount(
      client  : TWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToTokenAddress(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncAddress);
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

type
  TyVaultRegistry = class(TCustomContract)
  public
    constructor Create(aClient: TWeb3); reintroduce;
    procedure LatestVault(reserve: TAddress; callback: TAsyncAddress);
  end;

type
  TyVaultToken = class abstract(TERC20)
  public
    //------- read from contract -----------------------------------------------
    procedure PricePerShare(const block: string; callback: TAsyncQuantity);
    //------- helpers ----------------------------------------------------------
    procedure TokenToUnderlying(amount: BigInteger; callback: TAsyncQuantity);
    procedure UnderlyingToToken(amount: BigInteger; callback: TAsyncQuantity);
    procedure APY(period: TPeriod; callback: TAsyncFloat);
    //------- write to contract ------------------------------------------------
    procedure Deposit(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure Withdraw(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
  end;

implementation

uses
  // web3
  web3.eth,
  web3.eth.etherscan,
  web3.utils;

{ TyVaultV2 }

class procedure TyVaultV2.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  Self.UnderlyingToTokenAddress(client, reserve, procedure(token: TAddress; err: IError)
  var
    underlying: TERC20;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    underlying := TERC20.Create(client, reserve.Address);
    if Assigned(underlying) then
    begin
      underlying.ApproveEx(from, token, amount, procedure(rcpt: ITxReceipt; err: IError)
      begin
        try
          callback(rcpt, err);
        finally
          underlying.Free;
        end;
      end);
    end;
  end);
end;

class procedure TyVaultV2.TokenToUnderlyingAmount(
  client  : TWeb3;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncQuantity);
begin
  Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  var
    yVaultToken: TyVaultToken;
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    yVaultToken := TyVaultToken.Create(client, addr);
    try
      yVaultToken.TokenToUnderlying(amount, callback);
    finally
      yVaultToken.Free;
    end;
  end);
end;

class procedure TyVaultV2.UnderlyingToTokenAmount(
  client  : TWeb3;
  reserve : TReserve;
  amount  : BIgInteger;
  callback: TAsyncQuantity);
begin
  Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  var
    yVaultToken: TyVaultToken;
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    yVaultToken := TyVaultToken.Create(client, addr);
    try
      yVaultToken.UnderlyingToToken(amount, callback);
    finally
      yVaultToken.Free;
    end;
  end);
end;

class procedure TyVaultV2.UnderlyingToTokenAddress(
  client  : TWeb3;
  reserve : TReserve;
  callback: TAsyncAddress);
var
  registry: TyVaultRegistry;
begin
  registry := TyVaultRegistry.Create(client);
  try
    registry.LatestVault(reserve.Address, callback);
  finally
    registry.Free;
  end;
end;

class function TyVaultV2.Name: string;
begin
  Result := 'yVault v2';
end;

class function TyVaultV2.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Mainnet) and (reserve in [DAI, USDC]);
end;

class procedure TyVaultV2.APY(
  client  : TWeb3;
  reserve : TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);
begin
  Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  var
    yVaultToken: TyVaultToken;
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    yVaultToken := TyVaultToken.Create(client, addr);
    if Assigned(yVaultToken) then
    begin
      yVaultToken.APY(period, procedure(apy: Extended; err: IError)
      begin
        try
          callback(apy, err);
        finally
          yVaultToken.Free;
        end;
      end);
    end;
  end);
end;

class procedure TyVaultV2.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  Self.Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
    var
      yVaultToken: TyVaultToken;
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      yVaultToken := TyVaultToken.Create(client, addr);
      try
        yVaultToken.Deposit(from, amount, callback);
      finally
        yVaultToken.Free;
      end;
    end);
  end);
end;

class procedure TyVaultV2.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  var
    yVaultToken: TyVaultToken;
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    yVaultToken := TyVaultToken.Create(client, addr);
    try
      // step #1: get the yVaultToken balance
      yVaultToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          // step #2: multiply it by the current yVaultToken price
          Self.TokenToUnderlyingAmount(client, reserve, balance, procedure(output: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(output, nil);
          end);
      end);
    finally
      yVaultToken.Free;
    end;
  end);
end;

class procedure TyVaultV2.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  var
    yVaultToken: TyVaultToken;
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    yVaultToken := TyVaultToken.Create(client, addr);
    if Assigned(yVaultToken) then
    begin
      // step #1: get the yVaultToken balance
      yVaultToken.BalanceOf(from, procedure(balance: BigInteger; err: IError)
      begin
        try
          if Assigned(err) then
            callback(nil, 0, err)
          else
            // step #2: withdraw yVaultToken-amount in exchange for the underlying asset.
            yVaultToken.Withdraw(from, balance, procedure(rcpt: ITxReceipt; err: IError)
            begin
              if Assigned(err) then
                callback(nil, 0, err)
              else
                // step #3: from yVaultToken-balance to Underlying-balance
                Self.TokenToUnderlyingAmount(client, reserve, balance, procedure(output: BigInteger; err: IError)
                begin
                  if Assigned(err) then
                    callback(rcpt, 0, err)
                  else
                    callback(rcpt, output, nil);
                end);
            end);
        finally
          yVaultToken.Free;
        end;
      end);
    end;
  end);
end;

class procedure TyVaultV2.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  // step #1: from Underlying-amount to yVaultToken-amount
  Self.UnderlyingToTokenAmount(client, reserve, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    Self.UnderlyingToTokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
    var
      yVaultToken: TyVaultToken;
    begin
      if Assigned(err) then
      begin
        callback(nil, 0, err);
        EXIT;
      end;
      yVaultToken := TyVaultToken.Create(client, addr);
      if Assigned(yVaultToken) then
      try
        // step #2: withdraw yVaultToken-amount in exchange for the underlying asset.
        yVaultToken.Withdraw(from, input, procedure(rcpt: ITxReceipt; err: IError)
        begin
          if Assigned(err) then
            callback(nil, 0, err)
          else
            callback(rcpt, amount, nil);
        end);
      finally
        yVaultToken.Free;
      end;
    end);
  end);
end;

{ TyVaultRegistry }

constructor TyVaultRegistry.Create(aClient: TWeb3);
begin
  inherited Create(aClient, '0xE15461B18EE31b7379019Dc523231C57d1Cbc18c');
end;

procedure TyVaultRegistry.LatestVault(reserve: TAddress; callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'latestVault(address)', [reserve], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(ADDRESS_ZERO, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

{ TyVaultToken }

procedure TyVaultToken.PricePerShare(const block: string; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'pricePerShare()', block, [], callback);
end;

procedure TyVaultToken.TokenToUnderlying(amount: BigInteger; callback: TAsyncQuantity);
begin
  Self.PricePerShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsExtended * (price.AsExtended / 1e18)), nil);
  end);
end;

procedure TyVaultToken.UnderlyingToToken(amount: BIgInteger; callback: TAsyncQuantity);
begin
  Self.PricePerShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsExtended / (price.AsExtended / 1e18)), nil);
  end);
end;

procedure TyVaultToken.APY(period: TPeriod; callback: TAsyncFloat);
begin
  Self.PricePerShare(BLOCK_LATEST, procedure(currPrice: BigInteger; err: IError)
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
      Self.PricePerShare(web3.utils.toHex(bn), procedure(pastPrice: BigInteger; err: IError)
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

procedure TyVaultToken.Deposit(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract, 'deposit(uint256)', [web3.utils.toHex(amount)], callback);
end;

procedure TyVaultToken.Withdraw(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract, 'withdraw(uint256)', [web3.utils.toHex(amount)], callback);
end;

end.
