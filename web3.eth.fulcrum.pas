{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{        need tokens to test with?                                             }
{        1. make sure your wallet is set to the relevant testnet               }
{        2. go to https://faucet.kovan.network                                 }
{        3. get yourself some KETH (aka Kovan Ether)                           }
{        4. go to https://oasis.app/?network=kovan, click on Borrow            }
{        5. using your KETH as collateral, generate yourself some DAI          }
{                                                                              }
{******************************************************************************}

unit web3.eth.fulcrum;

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
  web3.eth.logs,
  web3.eth.types,
  web3.utils;

type
  EFulcrum = class(EWeb3);

  TFulcrum = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    class procedure TokenToUnderlying(
      client  : IWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncQuantity);
    class procedure UnderlyingToToken(
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

  TOnMint = reference to procedure(
    Sender     : TObject;
    Minter     : TAddress;
    TokenAmount: BigInteger;
    AssetAmount: BigInteger;
    Price      : BigInteger);
  TOnBurn = reference to procedure(
    Sender     : TObject;
    Burner     : TAddress;
    TokenAmount: BigInteger;
    AssetAmount: BigInteger;
    Price      : BigInteger);

  TiToken = class abstract(TERC20)
  strict private
    FOnMint: TOnMint;
    FOnBurn: TOnBurn;
    procedure SetOnMint(Value: TOnMint);
    procedure SetOnBurn(Value: TOnBurn);
  protected
    function  ListenForLatestBlock: Boolean; override;
    procedure OnLatestBlockMined(log: TLog); override;
  public
    constructor Create(aClient: IWeb3); reintroduce; overload; virtual; abstract;
    //------- read from contract -----------------------------------------------
    procedure AssetBalanceOf(owner: TAddress; callback: TAsyncQuantity);
    procedure LoanTokenAddress(callback: TAsyncAddress);
    procedure SupplyInterestRate(callback: TAsyncQuantity);
    procedure TokenPrice(callback: TAsyncQuantity);
    //------- write to contract ------------------------------------------------
    procedure Burn(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    procedure Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
    //------- events -----------------------------------------------------------
    property OnMint: TOnMint read FOnMint write SetOnMint;
    property OnBurn: TOnBurn read FOnBurn write SetOnBurn;
  end;

  TiDAI = class(TiToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TiUSDC = class(TiToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

  TiUSDT = class(TiToken)
  public
    constructor Create(aClient: IWeb3); override;
  end;

implementation

uses
  // Delphi
  System.Math,
  System.TypInfo;

type
  TiTokenClass = class of TiToken;

const
  iTokenClass: array[TReserve] of TiTokenClass = (
    TiDAI,
    TiUSDC,
    TiUSDT,
    nil
  );

{ TFulcrum }

// Approve the iToken contract to move your underlying asset.
class procedure TFulcrum.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  var iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  begin
    iToken.LoanTokenAddress(procedure(addr: TAddress; err: IError)
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
          erc20.ApproveEx(from, iToken.Contract, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            try
              callback(rcpt, err);
            finally
              erc20.Free;
            end;
          end);
        end;
      finally
        iToken.Free;
      end;
    end);
  end;
end;

class procedure TFulcrum.TokenToUnderlying(
  client  : IWeb3;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncQuantity);
begin
  var iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  try
    iToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(BigInteger.Create(amount.AsExtended * (price.AsExtended / 1e18)), nil);
    end);
  finally
    iToken.Free;
  end;
end;

class procedure TFulcrum.UnderlyingToToken(
  client  : IWeb3;
  reserve : TReserve;
  amount  : BIgInteger;
  callback: TAsyncQuantity);
begin
  var iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  try
    iToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(BigInteger.Create(amount.AsExtended / (price.AsExtended / 1e18)), nil);
    end);
  finally
    iToken.Free;
  end;
end;

class function TFulcrum.Name: string;
begin
  Result := 'Fulcrum';
end;

class function TFulcrum.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain in [Mainnet, Kovan]) and (reserve in [DAI, USDC, USDT]);
end;

// Returns the annual yield as a percentage with 4 decimals.
class procedure TFulcrum.APY(
  client  : IWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TAsyncFloat);
begin
  var iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  try
    iToken.SupplyInterestRate(procedure(value: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(BigInteger.Divide(value, BigInteger.Create(1e14)).AsInt64 / 1e4, nil);
    end);
  finally
    iToken.Free;
  end;
end;

// Deposits an underlying asset into the lending pool.
class procedure TFulcrum.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  // Before supplying an asset, we must first approve the iToken.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    var iToken := iTokenClass[reserve].Create(client);
    if Assigned(iToken) then
    try
      iToken.Mint(from, amount, callback);
    finally
      iToken.Free;
    end;
  end);
end;

// Returns how much underlying assets you are entitled to.
class procedure TFulcrum.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
begin
  var BalanceOf := procedure(callback: TAsyncQuantity)
  begin
    var iToken := iTokenClass[reserve].Create(client);
    if Assigned(iToken) then
    try
      iToken.AssetBalanceOf(owner, callback);
    finally
      iToken.Free;
    end;
  end;

  var Decimals := procedure(callback: TAsyncQuantity)
  begin
    var iToken := iTokenClass[reserve].Create(client);
    if Assigned(iToken) then
    try
      iToken.Decimals(callback);
    finally
      iToken.Free;
    end;
  end;

  BalanceOf(procedure(balance: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(balance, err);
      EXIT;
    end;
    Decimals(procedure(decimals: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(balance, err);
        EXIT;
      end;
      if reserve.Decimals = Power(10, decimals.AsInteger) then
        callback(balance, err)
      else
        callback(reserve.Scale(balance.AsExtended / Power(10, decimals.AsInteger)), err);
    end);
  end);
end;

// Redeems your balance of iTokens for the underlying asset.
class procedure TFulcrum.Withdraw(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    var iToken := iTokenClass[reserve].Create(client);
    if Assigned(iToken) then
    begin
      // step #1: get the iToken balance
      iToken.BalanceOf(addr, procedure(amount: BigInteger; err: IError)
      begin
        try
          if Assigned(err) then
          begin
            callback(nil, 0, err);
            EXIT;
          end;
          // step #2: redeem iToken-amount in exchange for the underlying asset
          iToken.Burn(from, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
            begin
              callback(nil, 0, err);
              EXIT;
            end;
            TokenToUnderlying(client, reserve, amount, procedure(output: BigInteger; err: IError)
            begin
              if Assigned(err) then
                callback(rcpt, 0, err)
              else
                callback(rcpt, output, nil);
            end);
          end);
        finally
          iToken.Free;
        end;
      end);
    end;
  end);
end;

class procedure TFulcrum.WithdrawEx(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
begin
  // step #1: from underlying-amount to iToken-amount
  UnderlyingToToken(client, reserve, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    var iToken := iTokenClass[reserve].Create(client);
    if Assigned(iToken) then
    try
      // step #2: redeem iToken-amount in exchange for the underlying asset
      iToken.Burn(from, input, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          callback(rcpt, amount, err);
      end);
    finally
      iToken.Free;
    end;
  end);
end;

{ TiToken }

function TiToken.ListenForLatestBlock: Boolean;
begin
  Result := inherited ListenForLatestBlock
            or Assigned(FOnMint)
            or Assigned(FOnBurn);
end;

procedure TiToken.OnLatestBlockMined(log: TLog);
begin
  inherited OnLatestBlockMined(log);

  if Assigned(FOnMint) then
    if log.isEvent('Mint(address,uint256,uint256,uint256)') then
      // emitted upon a successful Mint
      FOnMint(Self,
              log.Topic[1].toAddress, // minter
              log.Data[0].toBigInt,   // token amount
              log.Data[1].toBigInt,   // asset amount
              log.Data[2].toBigInt);  // price

  if Assigned(FOnBurn) then
    if log.isEvent('Burn(address,uint256,uint256,uint256)') then
      // emitted upon a successful Burn
      FOnBurn(Self,
              log.Topic[1].toAddress, // burner
              log.Data[0].toBigInt,   // token amount
              log.Data[1].toBigInt,   // asset amount
              log.Data[2].toBigInt);  // price
end;

procedure TiToken.SetOnMint(Value: TOnMint);
begin
  FOnMint := Value;
  EventChanged;
end;

procedure TiToken.SetOnBurn(Value: TOnBurn);
begin
  FOnBurn := Value;
  EventChanged;
end;

// Called to redeem owned iTokens for an equivalent amount of the underlying asset, at the current tokenPrice() rate.
// The supplier will receive the asset proceeds.
procedure TiToken.Burn(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(
        Client, from, Contract,
        'burn(address,uint256)', [addr, web3.utils.toHex(amount)], callback);
  end);
end;

// Called to deposit assets to the iToken, which in turn mints iTokens to the lender’s wallet at the current tokenPrice() rate.
// A prior ERC20 “approve” transaction should have been sent to the asset token for an amount greater than or equal to the specified amount.
// The supplier will receive the minted iTokens.
procedure TiToken.Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(
        Client, from, Contract,
        'mint(address,uint256)', [addr, web3.utils.toHex(amount)], callback);
  end);
end;

// Returns the user’s balance of the underlying asset, scaled by 1e18
// This is the same as multiplying the user’s token balance by the token price.
procedure TiToken.AssetBalanceOf(owner: TAddress; callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'assetBalanceOf(address)', [owner], callback);
end;

// Returns the underlying asset contract address for this iToken.
procedure TiToken.LoanTokenAddress(callback: TAsyncAddress);
begin
  web3.eth.call(Client, Contract, 'loanTokenAddress()', [], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(ADDRESS_ZERO, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

// Returns the aggregate rate that all lenders are receiving from borrowers, scaled by 1e18
procedure TiToken.SupplyInterestRate(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'supplyInterestRate()', [], callback);
end;

// Returns the current price of the iToken, scaled by 1e18
procedure TiToken.TokenPrice(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'tokenPrice()', [], callback);
end;

{ TiDAI }

constructor TiDAI.Create(aClient: IWeb3);
begin
  // https://bzx.network/itokens
  if aClient.Chain = Mainnet then
    inherited Create(aClient, '0x6b093998d36f2c7f0cc359441fbb24cc629d5ff0')
  else
    if aClient.Chain = Kovan then
      inherited Create(aClient, '0x73d0B4834Ba4ADa053d8282c02305eCdAC2304f0')
    else
      raise EFulcrum.CreateFmt('iDAI is not deployed on %s', [GetEnumName(TypeInfo(TChain), Integer(aClient.Chain))]);
end;

{ TiUSDC }

constructor TiUSDC.Create(aClient: IWeb3);
begin
  // https://bzx.network/itokens
  if aClient.Chain = Mainnet then
    inherited Create(aClient, '0x32e4c68b3a4a813b710595aeba7f6b7604ab9c15')
  else
    if aClient.Chain = Kovan then
      inherited Create(aClient, '0xaaC9822F31e5Aefb32bC228DcF259F23B49B9855')
    else
      raise EFulcrum.CreateFmt('iUSDC is not deployed on %s', [GetEnumName(TypeInfo(TChain), Integer(aClient.Chain))]);
end;

{ TiUSDT }

constructor TiUSDT.Create(aClient: IWeb3);
begin
  // https://bzx.network/itokens
  if aClient.Chain = Mainnet then
    inherited Create(aClient, '0x7e9997a38a439b2be7ed9c9c4628391d3e055d48')
  else
    if aClient.Chain = Kovan then
      inherited Create(aClient, '0x6b9F03e05423cC8D00617497890C0872FF33d4E8')
    else
      if aClient.Chain = BSC_main_net then
        inherited Create(aClient, '0xf326b42a237086f1de4e7d68f2d2456fc787bc01')
      else
        raise EFulcrum.CreateFmt('iUSDT is not deployed on %s', [GetEnumName(TypeInfo(TChain), Integer(aClient.Chain))]);
end;

end.
