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
  yVersion = (
    v2, // y.curve.fi
    v3  // busd.curve.fi
  );

  TyEarn = class(TLendingProtocol)
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
      version : yVersion;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToToken(
      client  : TWeb3;
      reserve : TReserve;
      version : yVersion;
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
    procedure APY(callback: TAsyncFloat);
    //------- write to contract ------------------------------------------------
    procedure Deposit(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure Withdraw(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
  end;

implementation

uses
  // Delphi
  System.DateUtils,
  System.SysUtils;

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

type
  TyTokenClass = class of TyToken;

const
  yTokenClass: array[TReserve] of array[yVersion] of TyTokenClass = (
    (TyDAIv2,  TyDAIv3),  // DAI
    (TyUSDCv2, TyUSDCv3), // USDC
    (TyUSDTv2, TyUSDTv3)  // USDT
  );

{ TyEarn }

class procedure TyEarn.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  yToken: TyToken;
begin
  yToken := yTokenClass[reserve][v2].Create(client);
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

class procedure TyEarn.TokenToUnderlying(
  client  : TWeb3;
  reserve : TReserve;
  version : yVersion;
  amount  : BigInteger;
  callback: TAsyncQuantity);
var
  yToken: TyToken;
begin
  yToken := yTokenClass[reserve][version].Create(client);
  if Assigned(yToken) then
  try
    yToken.TokenToUnderlying(amount, callback);
  finally
    yToken.Free;
  end;
end;

class procedure TyEarn.UnderlyingToToken(
  client  : TWeb3;
  reserve : TReserve;
  version : yVersion;
  amount  : BIgInteger;
  callback: TAsyncQuantity);
var
  yToken: TyToken;
begin
  yToken := yTokenClass[reserve][version].Create(client);
  if Assigned(yToken) then
  try
    yToken.UnderlyingToToken(amount, callback);
  finally
    yToken.Free;
  end;
end;

class function TyEarn.Name: string;
begin
  Result := 'yEarn';
end;

class function TyEarn.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := chain = Mainnet;
end;

class procedure TyEarn.APY(client: TWeb3; reserve: TReserve; callback: TAsyncFloat);
var
  yToken: TyToken;
begin
  yToken := yTokenClass[reserve][v2].Create(client);
  if Assigned(yToken) then
  begin
    yToken.APY(procedure(apy: Extended; err: IError)
    begin
      try
        callback(apy, err);
      finally
        yToken.Free;
      end;
    end);
  end;
end;

class procedure TyEarn.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  yToken: TyToken;
begin
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
    begin
      yToken := yTokenClass[reserve][v2].Create(client);
      try
        yToken.Deposit(from, amount, callback);
      finally
        yToken.Free;
      end;
    end;
  end);
end;

class procedure TyEarn.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
type
  TGetBalance = reference to procedure(version: yVersion; callback: TAsyncQuantity);
var
  getBalance: TGetBalance;
begin
  getBalance := procedure(version: yVersion; callback: TAsyncQuantity)
  var
    yToken: TyToken;
  begin
    yToken := yTokenClass[reserve][version].Create(client);
    if Assigned(yToken) then
    try
      // step #1: get the yToken balance
      yToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          // step #2: multiply it by the current yToken price
          TokenToUnderlying(client, reserve, version, balance, procedure(output: BigInteger; err: IError)
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

  getBalance(v2, procedure(qty2: BigInteger; err2: IError)
  begin
    if Assigned(err2) then
      callback(0, err2)
    else
      getBalance(v3, procedure(qty3: BigInteger; err3: IError)
      begin
        if Assigned(err3) then
          callback(0, err3)
        else
          callback(qty2 + qty3, nil);
      end);
  end);
end;

class procedure TyEarn.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
type
  TGetBalance = reference to procedure(version: yVersion; callback: TAsyncQuantity);
  TDoWithdraw = reference to procedure(version: yVersion; callback: TAsyncReceiptEx);
var
  getBalance: TGetBalance;
  doWithdraw: TDoWithdraw;
begin
  getBalance := procedure(version: yVersion; callback: TAsyncQuantity)
  var
    yToken: TyToken;
  begin
    yToken := yTokenClass[reserve][version].Create(client);
    if Assigned(yToken) then
    try
      yToken.BalanceOf(from, callback);
    finally
      yToken.Free;
    end;
  end;

  doWithdraw := procedure(version: yVersion; callback: TAsyncReceiptEx)
  var
    yToken: TyToken;
  begin
    // step #1: get the yToken balance
    getBalance(version, procedure(balance: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        if balance = 0 then
          callback(nil, 0, nil)
        else
        begin
          yToken := yTokenClass[reserve][version].Create(client);
          if Assigned(yToken) then
          try
            // step #2: withdraw yToken-amount in exchange for the underlying asset.
            yToken.Withdraw(from, balance, procedure(rcpt: ITxReceipt; err: IError)
            begin
              if Assigned(err) then
                callback(nil, 0, err)
              else
                // step #3: from yToken-balance to Underlying-balance
                TokenToUnderlying(client, reserve, version, balance, procedure(output: BigInteger; err: IError)
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
        end;
    end);
  end;

  doWithdraw(v2, procedure(rcpt2: ITxReceipt; qty2: BigInteger; err2: IError)
  begin
    if Assigned(err2) then
      callback(nil, 0, err2)
    else
      doWithdraw(v3, procedure(rcpt3: ITxReceipt; qty3: BigInteger; err3: IError)
      begin
        if Assigned(err3) then
          callback(nil, 0, err3)
        else
          if Assigned(rcpt2) then
            callback(rcpt2, qty2 + qty3, nil)
          else
            callback(rcpt3, qty2 + qty3, nil);
      end);
  end);
end;

class procedure TyEarn.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
var
  yToken: TyToken;
begin
  // step #1: from Underlying-amount to yToken-amount
  UnderlyingToToken(client, reserve, v2, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    yToken := yTokenClass[reserve][v2].Create(client);
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
      callback(nil, err)
    else
    begin
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

procedure TyToken.APY(callback: TAsyncFloat);
var
  oneMonthAgo: TUnixDateTime;
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(currPrice: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    oneMonthAgo := DateTimeToUnix(Now, False) - 60 * 60 * 24 * 30;
    getBlockNumberByTimestamp(client.Chain, oneMonthAgo, client.ETHERSCAN_API_KEY, procedure(bn: BigInteger; err: IError)
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
        callback(((currPrice.AsExtended / pastPrice.AsExtended - 1) * 100) * 12, nil);
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

{ TyDAIv3 }

class function TyDAIv3.DeployedAt: TAddress;
begin
  Result := TAddress.New('0xC2cB1040220768554cf699b0d863A3cd4324ce32');
end;

{ TyUSDCv3 }

class function TyUSDCv3.DeployedAt: TAddress;
begin
  Result := TAddress.New('0x26EA744E5B887E5205727f55dFBE8685e3b21951');
end;

{ TyUSDTv2 }

class function TyUSDTv3.DeployedAt: TAddress;
begin
  Result := TAddress.New('0xE6354ed5bC4b393a5Aad09f21c46E101e692d447');
end;

end.
