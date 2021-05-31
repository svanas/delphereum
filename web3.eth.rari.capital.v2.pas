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

unit web3.eth.rari.capital.v2;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.etherscan,
  web3.eth.types,
  web3.utils;

type
  TRari = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
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
      _client : TWeb3;
      _from   : TPrivateKey;
      _reserve: TReserve;
      _amount : BigInteger;
      callback: TAsyncReceiptEx); override;
  end;

  TCustomRariPoolManager = class abstract(TCustomContract)
  public
    constructor Create(aClient: TWeb3); reintroduce;
    // Address where this manager is deployed.
    class function DeployedAt: TAddress; virtual; abstract;
    // Address where the pool token is deployed.
    class function PoolToken: TAddress; virtual; abstract;
    // Returns the total balance in USD (scaled by 1e18) supplied by `owner`.
    procedure BalanceOf(owner: TAddress; callback: TAsyncQuantity);
    // Returns an array of currency codes currently accepted for deposits.
    procedure GetAcceptedCurrencies(callback: TAsyncTuple);
    // Returns the total balance supplied by users to the pool.
    // (all pool token holders' funds but not unclaimed fees) in USD (scaled by 1e18).
    procedure GetFundBalance(const block: string; callback: TAsyncQuantity);
    // Deposits funds to the pool in exchange for pool tokens.
    procedure Deposit(
      from: TPrivateKey;          // supplier of the funds, and receiver of pool tokens.
      const currencyCode: string; // The currency code of the token to be deposited.
      amount: BigInteger;         // The amount of tokens to be deposited.
      callback: TAsyncReceipt);
    // Withdraws funds from the pool in exchange for pool tokens.
    procedure Withdraw(
      from: TPrivateKey;          // supplier of pool tokens, and receiver of the funds.
      const currencyCode: string; // The currency code of the token to be withdrawn.
      amount: BigInteger;         // The amount of tokens to be withdrawn.
      callback: TAsyncReceipt);
    // Get the exchange rate of pool tokens in USD (scaled by 1e18).
    procedure GetExchangeRate(const block: string; callback: TAsyncFloat);
    // Returns the annual yield as a percentage.
    procedure APY(period: TPeriod; callback: TAsyncFloat);
  end;

  TRariPoolManagerUSDC = class(TCustomRariPoolManager)
  public
    // Address where this manager is deployed.
    class function DeployedAt: TAddress; override;
    // Address where the pool token is deployed.
    class function PoolToken: TAddress; override;
  end;

  TRariPoolManagerDAI = class(TCustomRariPoolManager)
  public
    // Address where this manager is deployed.
    class function DeployedAt: TAddress; override;
    // Address where the pool token is deployed.
    class function PoolToken: TAddress; override;
  end;

implementation

uses
  // Delphi
  System.Math,
  System.SysUtils,
  System.Types,
  // web3
  web3.eth.rari.capital.api;

type
  TRariPoolManagerClass = class of TCustomRariPoolManager;

const
  RariPoolManager: array[TReserve] of TRariPoolManagerClass = (
    TRariPoolManagerDAI,
    TRariPoolManagerUSDC,
    nil,
    nil
  );

{ TRari }

class procedure TRari.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  var erc20 := TERC20.Create(client, reserve.Address);
  if Assigned(erc20) then
  begin
    erc20.ApproveEx(from, RariPoolManager[reserve].DeployedAt, amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      try
        callback(rcpt, err);
      finally
        erc20.Free;
      end;
    end);
  end;
end;

class function TRari.Name: string;
begin
  Result := 'Rari';
end;

class function TRari.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain = Mainnet) and (reserve in [DAI, USDC]);
end;

class procedure TRari.APY(
  client  : TWeb3;
  reserve : TReserve;
  period  : TPeriod;
  callback: TAsyncFloat);

  function getAPY(reserve: TReserve; callback: TAsyncFloat): IAsyncResult;
  begin
    Result := web3.eth.rari.capital.api.stats(procedure(stats: IRariStats; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        if reserve = DAI then
          callback(stats.DaiPoolAPY, nil)
        else
          callback(stats.StablePoolAPY, nil);
    end);
  end;

begin
  getAPY(reserve, procedure(apy: Extended; err: IError)
  begin
    if (apy > 0) and not Assigned(err) then
    begin
      callback(apy, err);
      EXIT;
    end;
    var manager := RariPoolManager[reserve].Create(client);
    if Assigned(manager) then
    begin
      manager.APY(period, procedure(apy: Extended; err: IError)
      begin
        try
          if Assigned(err) or (not IsNaN(apy)) or (period = Low(TPeriod)) then
          begin
            callback(apy, err);
            EXIT;
          end;
          Self.APY(client, reserve, Pred(period), callback);
        finally
          manager.Free;
        end;
      end);
    end;
  end);
end;

class procedure TRari.Deposit(
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
    var manager := RariPoolManager[reserve].Create(client);
    try
      manager.Deposit(from, reserve.Symbol, amount, callback);
    finally
      manager.Free;
    end;
  end);
end;

class procedure TRari.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  var manager := RariPoolManager[reserve].Create(client);
  if Assigned(manager) then
  try
    manager.BalanceOf(owner, procedure(usd: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(usd, err)
      else
        if reserve.Decimals = 1e18 then
          callback(usd, err)
        else
          callback(reserve.Scale(usd.AsExtended / 1e18), err);
    end);
  finally
    manager.Free;
  end;
end;

class procedure TRari.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  from.Address(procedure(owner: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    var token := TERC20.Create(client, RariPoolManager[reserve].PoolToken);
    if Assigned(token) then
    begin
      // step #1: get the pool token balance
      token.BalanceOf(owner, procedure(input: BigInteger; err: IError)
      begin
        try
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          // step #2: approve the pool manager to burn pool tokens
          token.ApproveEx(from, RariPoolManager[reserve].DeployedAt, input, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
            begin
              callback(nil, 0, err);
              EXIT;
            end;
            // step #3: get the USD balance
            Self.Balance(client, owner, reserve, procedure(output: BigInteger; err: IError)
            begin
              if Assigned(err) then
              begin
                callback(nil, 0, err);
                EXIT;
              end;
              var manager := RariPoolManager[reserve].Create(client);
              try
                // step #4: withdraws funds from the pool in exchange for pool tokens
                manager.Withdraw(from, reserve.Symbol, input, procedure(rcpt: ITxReceipt; err: IError)
                begin
                  if Assigned(err) then
                    callback(nil, 0, err)
                  else
                    callback(rcpt, output, nil);
                end);
              finally
                manager.Free;
              end;
            end);
          end);
        finally
          token.Free;
        end;
      end);
    end;
  end);
end;

class procedure TRari.WithdrawEx(
  _client : TWeb3;
  _from   : TPrivateKey;
  _reserve: TReserve;
  _amount : BigInteger;
  callback: TAsyncReceiptEx);
begin
  callback(nil, 0, TNotImplemented.Create);
end;

{ TCustomRariPoolManager }

constructor TCustomRariPoolManager.Create(aClient: TWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

// Returns the total balance in USD (scaled by 1e18) supplied by `owner`.
procedure TCustomRariPoolManager.BalanceOf(owner: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'balanceOf(address)', [owner], callback);
end;

// Returns an array of currency codes currently accepted for deposits.
procedure TCustomRariPoolManager.GetAcceptedCurrencies(callback: TAsyncTuple);
begin
  web3.eth.call(Client, Contract, 'getAcceptedCurrencies()', [], callback);
end;

// Returns the total balance supplied by users to the pool.
// (all pool token holders' funds but not unclaimed fees) in USD (scaled by 1e18).
procedure TCustomRariPoolManager.GetFundBalance(const block: string; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'getFundBalance()', block, [], callback);
end;

// Deposits funds to the pool in exchange for pool tokens.
// Please note that you must approve this manager to transfer at least `amount`.
procedure TCustomRariPoolManager.Deposit(
  from: TPrivateKey;          // supplier of the funds, and receiver of pool tokens.
  const currencyCode: string; // The currency code of the token to be deposited.
  amount: BigInteger;         // The amount of tokens to be deposited.
  callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract,
    'deposit(string,uint256)',
    [currencyCode, web3.utils.toHex(amount)], 900000, callback);
end;

// Withdraws funds from the pool in exchange for pool tokens.
// Please note that you must approve this manager to burn the necessary amount of pool tokens.
procedure TCustomRariPoolManager.Withdraw(
  from: TPrivateKey;          // supplier of pool tokens, and receiver of the funds.
  const currencyCode: string; // The currency code of the token to be withdrawn.
  amount: BigInteger;         // The amount of tokens to be withdrawn.
  callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract,
    'withdraw(string,uint256)',
    [currencyCode, web3.utils.toHex(amount)], 1200000, callback);
end;

// Get the exchange rate of pool tokens in USD (scaled by 1e18).
procedure TCustomRariPoolManager.GetExchangeRate(
  const block: string;
  callback   : TAsyncFloat);
begin
  var client := Self.Client;
  Self.GetFundBalance(block, procedure(balance: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    var token := TERC20.Create(client, Self.PoolToken);
    try
      token.TotalSupply(block, procedure(totalSupply: BigInteger; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(0, err);
          EXIT;
        end;
        callback(balance.AsExtended / totalSupply.AsExtended, nil);
      end);
    finally
      token.Free;
    end;
  end);
end;

// Returns the annual yield as a percentage.
procedure TCustomRariPoolManager.APY(period: TPeriod; callback: TAsyncFloat);
begin
  Self.GetExchangeRate(BLOCK_LATEST, procedure(currRate: Extended; err: IError)
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
      Self.GetExchangeRate(web3.utils.toHex(bn), procedure(pastRate: Extended; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(0, err);
          EXIT;
        end;
        if IsNaN(currRate) or IsNaN(pastRate) then
          callback(NaN, nil)
        else
          callback(period.ToYear(currRate / pastRate - 1) * 100, nil);
      end);
    end);
  end);
end;

{ TRariPoolManagerUSDC }

class function TRariPoolManagerUSDC.DeployedAt: TAddress;
begin
  Result := TAddress('0xC6BF8C8A55f77686720E0a88e2Fd1fEEF58ddf4a');
end;

class function TRariPoolManagerUSDC.PoolToken: TAddress;
begin
  Result := TAddress('0x016bf078ABcaCB987f0589a6d3BEAdD4316922B0');
end;

{ TRariPoolManagerDAI }

class function TRariPoolManagerDAI.DeployedAt: TAddress;
begin
  Result := TAddress('0xB465BAF04C087Ce3ed1C266F96CA43f4847D9635');
end;

class function TRariPoolManagerDAI.PoolToken: TAddress;
begin
  Result := TAddress('0x0833cfcb11A5ba89FbAF73a407831c98aD2D7648');
end;

end.
