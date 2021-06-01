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

unit web3.eth.idle.finance.v4;

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
  web3.eth.types,
  web3.utils;

type
  TIdle = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    class procedure IdleToUnderlying(
      client  : IWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToIdle(
      client  : IWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client  : IWeb3;
      reserve : TReserve;
      _period : TPeriod;
      callback: TAsyncFloat); override;
    class procedure Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); override;
    class procedure Balance(
      client  : IWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); override;
    class procedure Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceiptEx); override;
    class procedure WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceiptEx); override;
  end;

  TIdleViewHelper = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure GetFullAPR(idleToken: TAddress; callback: TAsyncQuantity);
  end;

  TIdleToken = class abstract(TERC20)
  public
    constructor Create(aClient: IWeb3); reintroduce; overload; virtual; abstract;
    procedure Token(callback: TAsyncAddress);
    procedure GetAvgAPR(callback: TAsyncQuantity);
    procedure GetFullAPR(callback: TAsyncQuantity);
    procedure TokenPrice(callback: TAsyncQuantity);
    procedure MintIdleToken(
      from              : TPrivateKey; // supplier of the underlying asset, and receiver of IdleTokens
      amount            : BigInteger;  // amount of underlying asset to be lent
      skipWholeRebalance: Boolean;     // triggers a rebalance of the whole pools if true
      referral          : TAddress;    // address for eventual future referral program
      callback          : TAsyncReceipt);
    procedure RedeemIdleToken(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
  end;

  TIdleDAI = class(TIdleToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TIdleUSDC = class(TIdleToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TIdleUSDT = class(TIdleToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

implementation

type
  TIdleTokenClass = class of TIdleToken;

const
  IdleTokenClass: array[TReserve] of TIdleTokenClass = (
    TIdleDAI,
    TIdleUSDC,
    TIdleUSDT,
    nil
  );

{ TIdle }

class procedure TIdle.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  var IdleToken := IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  begin
    IdleToken.Token(procedure(addr: TAddress; err: IError)
    begin
      try
        if Assigned(err) then
        begin
          callback(nil, err);
          EXIT;
        end;
        var erc20 := TERC20.Create(client, addr);
        if Assigned(erc20) then
        begin
          erc20.ApproveEx(from, IdleToken.Contract, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            try
              callback(rcpt, err);
            finally
              erc20.Free;
            end;
          end);
        end;
      finally
        IdleToken.Free;
      end;
    end);
  end;
end;

class procedure TIdle.IdleToUnderlying(
  client  : IWeb3;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncQuantity);
begin
  var IdleToken := IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  try
    IdleToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(reserve.Scale(reserve.Unscale(amount) * (price.AsExtended / 1e18)), nil);
    end);
  finally
    IdleToken.free;
  end;
end;

class procedure TIdle.UnderlyingToIdle(
  client  : IWeb3;
  reserve : TReserve;
  amount  : BIgInteger;
  callback: TAsyncQuantity);
begin
  var IdleToken := IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  try
    IdleToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(reserve.Scale(reserve.Unscale(amount) / (price.AsExtended / 1e18)), nil);
    end);
  finally
    IdleToken.free;
  end;
end;

class function TIdle.Name: string;
begin
  Result := 'Idle';
end;

class function TIdle.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (
    (chain = Mainnet) and (reserve = USDT)
  ) or (
    (chain in [Mainnet, Kovan]) and (reserve in [DAI, USDC])
  );
end;

class procedure TIdle.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TAsyncFloat);
begin
  var IdleToken := IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  try
    IdleToken.GetFullAPR(procedure(apr: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(apr.AsExtended / 1e18, nil);
    end);
  finally
    IdleToken.Free;
  end;
end;

class procedure TIdle.Deposit(
  client  : IWeb3;
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
    var IdleToken := IdleTokenClass[reserve].Create(client);
    if Assigned(IdleToken) then
    try
      IdleToken.MintIdleToken(from, amount, True, ADDRESS_ZERO, callback);
    finally
      IdleToken.Free;
    end;
  end);
end;

class procedure TIdle.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  var IdleToken := IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  try
    // step #1: get the IdleToken balance
    IdleToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      // step #2: multiply it by the current IdleToken price
      IdleToUnderlying(client, reserve, balance, procedure(output: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(output, nil);
      end);
    end);
  finally
    IdleToken.Free;
  end;
end;

class procedure TIdle.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  var IdleToken := IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  begin
    // step #1: get the IdleToken balance
    IdleToken.BalanceOf(from, procedure(balance: BigInteger; err: IError)
    begin
      try
        if Assigned(err) then
        begin
          callback(nil, 0, err);
          EXIT;
        end;
        // step #2: redeem IdleToken-amount in exchange for the underlying asset.
        IdleToken.RedeemIdleToken(from, balance, procedure(rcpt: ITxReceipt; err: IError)
        begin
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          IdleToUnderlying(client, reserve, balance, procedure(output: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(rcpt, 0, err)
            else
              callback(rcpt, output, nil);
          end);
        end);
      finally
        IdleToken.Free;
      end;
    end);
  end;
end;

class procedure TIdle.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  // step #1: from Underlying-amount to IdleToken-amount
  UnderlyingToIdle(client, reserve, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    var IdleToken := IdleTokenClass[reserve].Create(client);
    if Assigned(IdleToken) then
    try
      // step #2: redeem IdleToken-amount in exchange for the underlying asset.
      IdleToken.RedeemIdleToken(from, input, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          callback(rcpt, amount, nil);
      end);
    finally
      IdleToken.Free;
    end;
  end);
end;

{ TIdleViewHelper }

constructor TIdleViewHelper.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0xae2Ebae0a2bC9a44BdAa8028909abaCcd336b8f5');
end;

procedure TIdleViewHelper.GetFullAPR(idleToken: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'getFullAPR(address)', [idleToken], callback);
end;

{ TIdleToken }

// Returns the underlying asset contract address for this IdleToken.
procedure TIdleToken.Token(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'token()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(ADDRESS_ZERO, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

// Get base layer aggregated APR of IdleToken.
// This does not take into account fees, unlent percentage and additional APR given by governance tokens.
procedure TIdleToken.GetAvgAPR(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'getAvgAPR()', [], callback);
end;

// Get current IdleToken average APR considering governance tokens.
procedure TIdleToken.GetFullAPR(callback: TAsyncQuantity);
begin
  var helper := TIdleViewHelper.Create(Self.Client);
  try
    helper.GetFullAPR(Self.Contract, callback);
  finally
    helper.Free;
  end;
end;

// Current IdleToken price, in underlying (eg. DAI) terms.
procedure TIdleToken.TokenPrice(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'tokenPrice()', [], callback);
end;

// Transfers the amount of underlying assets to IdleToken contract and then mints interest-bearing tokens with that amount.
procedure TIdleToken.MintIdleToken(
  from              : TPrivateKey; // supplier of the underlying asset, and receiver of IdleTokens
  amount            : BigInteger;  // amount of underlying asset to be lent
  skipWholeRebalance: Boolean;     // triggers a rebalance of the whole pools if true
  referral          : TAddress;    // address for eventual future referral program
  callback          : TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract,
    'mintIdleToken(uint256,bool,address)',
    [web3.utils.toHex(amount), skipWholeRebalance, referral], callback);
end;

// Redeems your underlying balance by burning your IdleTokens.
procedure TIdleToken.RedeemIdleToken(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract,
    'redeemIdleToken(uint256)', [web3.utils.toHex(amount)], callback);
end;

{ TIdleDAI }

constructor TIdleDAI.Create(aClient: IWeb3);
begin
  if aClient.Chain = Kovan then
    inherited Create(aClient, '0x295CA5bC5153698162dDbcE5dF50E436a58BA21e')
  else
    inherited Create(aClient, '0x3fe7940616e5bc47b0775a0dccf6237893353bb4');
end;

{ TIdleUSDC }

constructor TIdleUSDC.Create(aClient: IWeb3);
begin
  if aClient.Chain = Kovan then
    inherited Create(aClient, '0x0de23D3bc385a74E2196cfE827C8a640B8774B9f')
  else
    inherited Create(aClient, '0x5274891bEC421B39D23760c04A6755eCB444797C');
end;

{ TIdleUSDT }

constructor TIdleUSDT.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0xF34842d05A1c888Ca02769A633DF37177415C2f8');
end;

end.
