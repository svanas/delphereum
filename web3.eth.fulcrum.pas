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
  web3.eth.types;

type
  EFulcrum = class(EWeb3);

  TFulcrum = class(TLendingProtocol)
  public
    class procedure APY(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncFloat); override;
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
    constructor Create(aClient: TWeb3); overload; virtual; abstract;
    //------- read from contract -----------------------------------------------
    procedure SupplyInterestRate(callback: TAsyncQuantity);
    procedure TokenPrice(callback: TAsyncQuantity);
    //------- write to contract ------------------------------------------------
    procedure Burn(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
    procedure Mint(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
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

implementation

type
  TiTokenClass = class of TiToken;

const
  iTokenClass: array[TReserve] of TiTokenClass = (
    TiDAI,
    TiUSDC
  );

{ TFulcrum }

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
              toBigInt(log.Data[0]),
              toBigInt(log.Data[1]),
              toBigInt(log.Data[2]));

  if Assigned(FOnBurn) then
    if log.isEvent('Burn(address,uint256,uint256,uint256)') then
      // emitted upon a successful Burn
      FOnBurn(Self,
              TAddress.New(log.Topic[1]),
              toBigInt(log.Data[0]),
              toBigInt(log.Data[1]),
              toBigInt(log.Data[2]));
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
procedure TiToken.Burn(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract, 'burn(address,uint256)', [from.Address, amount], callback);
end;

// Called to deposit assets to the iToken, which in turn mints iTokens to the lender’s wallet at the current tokenPrice() rate.
// A prior ERC20 “approve” transaction should have been sent to the asset token for an amount greater than or equal to the specified amount.
// The supplier will receive the minted iTokens.
procedure TiToken.Mint(from: TPrivateKey; amount: UInt64; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract, 'mint(address,uint256)', [from.Address, amount], callback);
end;

// Returns the aggregate rate that all lenders are receiving from borrowers, scaled by 1e20
procedure TiToken.SupplyInterestRate(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'supplyInterestRate()', [], procedure(qty: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(qty, nil);
  end);
end;

// Returns the current price of the iToken, scaled by 1e18
procedure TiToken.TokenPrice(callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract, 'tokenPrice()', [], procedure(qty: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(BigInteger.Zero, err)
    else
      callback(qty, nil);
  end);
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

end.
