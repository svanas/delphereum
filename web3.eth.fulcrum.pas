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
    constructor Create(aClient: TWeb3); reintroduce; overload; virtual; abstract;
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
    constructor Create(aClient: TWeb3); override;
  end;

  TiUSDC = class(TiToken)
  public
    constructor Create(aClient: TWeb3); override;
  end;

  TiUSDT = class(TiToken)
  public
    constructor Create(aClient: TWeb3); override;
  end;

implementation

type
  TiTokenClass = class of TiToken;

const
  iTokenClass: array[TReserve] of TiTokenClass = (
    TiDAI,
    TiUSDC,
    TiUSDT
  );

{ TFulcrum }

// Approve the iToken contract to move your underlying asset.
class procedure TFulcrum.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  erc20 : TERC20;
  iToken: TiToken;
begin
  iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  begin
    iToken.LoanTokenAddress(procedure(addr: TAddress; err: IError)
    begin
      try
        if Assigned(err) then
          callback(nil, err)
        else
        begin
          erc20 := TERC20.Create(client, addr);
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
        end;
      finally
        iToken.Free;
      end;
    end);
  end;
end;

class function TFulcrum.Name: string;
begin
  Result := 'Fulcrum';
end;

class function TFulcrum.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  if reserve = DAI then
    Result := chain in [Mainnet, Ganache, Kovan]
  else
    Result := chain in [Mainnet, Ganache];
end;

// Returns the annual yield as a percentage with 4 decimals.
class procedure TFulcrum.APY(client: TWeb3; reserve: TReserve; callback: TAsyncFloat);
var
  iToken: TiToken;
begin
  iToken := iTokenClass[reserve].Create(client);
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
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  iToken: TiToken;
begin
  // Before supplying an asset, we must first approve the iToken.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
    begin
      iToken := iTokenClass[reserve].Create(client);
      try
        iToken.Mint(from, amount, callback);
      finally
        iToken.Free;
      end;
    end;
  end);
end;

// Returns how much underlying assets you are entitled to.
class procedure TFulcrum.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
var
  iToken: TiToken;
begin
  iToken := iTokenClass[reserve].Create(client);
  try
    iToken.AssetBalanceOf(owner, callback);
  finally
    iToken.Free;
  end;
end;

// Redeems your balance of iTokens for the underlying asset.
class procedure TFulcrum.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
var
  iToken: TiToken;
begin
  iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  begin
    iToken.BalanceOf(from.Address, procedure(amount: BigInteger; err: IError)
    begin
      try
        if Assigned(err) then
          callback(nil, 0, err)
        else
          iToken.Burn(from, amount, procedure(rcpt: ITxReceipt; err: IError)
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
end;

class procedure TFulcrum.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
var
  iToken: TiToken;
begin
  iToken := iTokenClass[reserve].Create(client);
  if Assigned(iToken) then
  begin
    iToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      try
        if Assigned(err) then
          callback(nil, 0, err)
        else
          iToken.Burn(from, BigInteger.Create(amount.AsExtended / (price.AsExtended / 1e18)),
            procedure(rcpt: ITxReceipt; err: IError)
            begin
              if Assigned(err) then
                callback(nil, 0, err)
              else
                callback(rcpt, BigInteger.Create(amount.AsExtended / (price.AsExtended / 1e18)), err);
            end);
      finally
        iToken.Free;
      end;
    end);
  end;
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
              TAddress.New(log.Topic[1]),
              log.Data[0].toBigInt,
              log.Data[1].toBigInt,
              log.Data[2].toBigInt);

  if Assigned(FOnBurn) then
    if log.isEvent('Burn(address,uint256,uint256,uint256)') then
      // emitted upon a successful Burn
      FOnBurn(Self,
              TAddress.New(log.Topic[1]),
              log.Data[0].toBigInt,
              log.Data[1].toBigInt,
              log.Data[2].toBigInt);
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
  web3.eth.write(
    Client, from, Contract,
    'burn(address,uint256)', [from.Address, web3.utils.toHex(amount)], callback);
end;

// Called to deposit assets to the iToken, which in turn mints iTokens to the lender’s wallet at the current tokenPrice() rate.
// A prior ERC20 “approve” transaction should have been sent to the asset token for an amount greater than or equal to the specified amount.
// The supplier will receive the minted iTokens.
procedure TiToken.Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(
    Client, from, Contract,
    'mint(address,uint256)', [from.Address, web3.utils.toHex(amount)], callback);
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
      callback('', err)
    else
      callback(TAddress.New(hex), nil)
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

constructor TiDAI.Create(aClient: TWeb3);
begin
  // https://bzx.network/itokens
  case aClient.Chain of
    Mainnet, Ganache:
      inherited Create(aClient, '0x493c57c4763932315a328269e1adad09653b9081');
    Ropsten:
      raise EFulcrum.Create('iDAI is not supported on Ropsten');
    Rinkeby:
      raise EFulcrum.Create('iDAI is not supported on Rinkeby');
    Goerli:
      raise EFulcrum.Create('iDAI is not supported on Goerli');
    Kovan:
      inherited Create(aClient, '0x6c1e2b0f67e00c06c8e2be7dc681ab785163ff4d');
  end;
end;

{ TiUSDC }

constructor TiUSDC.Create(aClient: TWeb3);
begin
  // https://bzx.network/itokens
  case aClient.Chain of
    Mainnet, Ganache:
      inherited Create(aClient, '0xF013406A0B1d544238083DF0B93ad0d2cBE0f65f');
    Ropsten:
      raise EFulcrum.Create('iUSDC is not supported on Ropsten');
    Rinkeby:
      raise EFulcrum.Create('iUSDC is not supported on Rinkeby');
    Goerli:
      raise EFulcrum.Create('iUSDC is not supported on Goerli');
    Kovan:
      raise EFulcrum.Create('iUSDC is not supported on Kovan');
  end;
end;

{ TiUSDT }

constructor TiUSDT.Create(aClient: TWeb3);
begin
  // https://bzx.network/itokens
  case aClient.Chain of
    Mainnet, Ganache:
      inherited Create(aClient, '0x8326645f3aa6de6420102fdb7da9e3a91855045b');
    Ropsten:
      raise EFulcrum.Create('iUSDT is not supported on Ropsten');
    Rinkeby:
      raise EFulcrum.Create('iUSDT is not supported on Rinkeby');
    Goerli:
      raise EFulcrum.Create('iUSDT is not supported on Goerli');
    Kovan:
      raise EFulcrum.Create('iUSDT is not supported on Kovan');
  end;
end;

end.
