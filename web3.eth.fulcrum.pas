{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
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
  // Delphi
  System.Math,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.etherscan,
  web3.eth.logs,
  web3.eth.types,
  web3.utils;

type
  TFulcrum = class(TLendingProtocol)
  protected
    class procedure Approve(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    class procedure TokenToUnderlying(
      const client  : IWeb3;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<BigInteger, IError>);
    class procedure UnderlyingToToken(
      const client  : IWeb3;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<BigInteger, IError>);
  public
    class function Name: string; override;
    class function Supports(
      const chain  : TChain;
      const reserve: TReserve): Boolean; override;
    class procedure APY(
      const client   : IWeb3;
      const etherscan: IEtherscan;
      const reserve  : TReserve;
      const period   : TPeriod;
      const callback : TProc<Double, IError>); override;
    class procedure Deposit(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>); override;
    class procedure Balance(
      const client  : IWeb3;
      const owner   : TAddress;
      const reserve : TReserve;
      const callback: TProc<BigInteger, IError>); override;
    class procedure Withdraw(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const callback: TProc<ITxReceipt, BigInteger, IError>); override;
    class procedure WithdrawEx(
      const client  : IWeb3;
      const from    : TPrivateKey;
      const reserve : TReserve;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, BigInteger, IError>); override;
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

  IiToken = interface(IERC20)
    //------- read from contract -----------------------------------------------
    procedure AssetBalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
    procedure LoanTokenAddress(const callback: TProc<TAddress, IError>);
    procedure SupplyInterestRate(const callback: TProc<BigInteger, IError>);
    procedure TokenPrice(const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Burn(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Mint(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    //------- events -----------------------------------------------------------
    function SetOnMint(const Value: TOnMint): IiToken;
    function SetOnBurn(const Value: TOnBurn): IiToken;
  end;

implementation

{ TiToken }

type
  TiToken = class(TERC20, IiToken)
  strict private
    FOnMint: TOnMint;
    FOnBurn: TOnBurn;
  protected
    function  ListenForLatestBlock: Boolean; override;
    procedure OnLatestBlockMined(log: PLog; err: IError); override;
  public
    //------- read from contract -----------------------------------------------
    procedure AssetBalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
    procedure LoanTokenAddress(const callback: TProc<TAddress, IError>);
    procedure SupplyInterestRate(const callback: TProc<BigInteger, IError>);
    procedure TokenPrice(const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Burn(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Mint(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    //------- events -----------------------------------------------------------
    function SetOnMint(const Value: TOnMint): IiToken;
    function SetOnBurn(const Value: TOnBurn): IiToken;
  end;

function iDAI(const aClient: IWeb3): IiToken;
begin
  // https://bzx.network/itokens
  Result := TiToken.Create(aClient, '0x6b093998d36f2c7f0cc359441fbb24cc629d5ff0');
end;

function iUSDC(const aClient: IWeb3): IiToken;
begin
  // https://bzx.network/itokens
  Result := TiToken.Create(aClient, '0x32e4c68b3a4a813b710595aeba7f6b7604ab9c15');
end;

function iUSDT(const aClient: IWeb3): IiToken;
begin
  // https://bzx.network/itokens
  if aClient.Chain = BNB then
    Result := TiToken.Create(aClient, '0xf326b42a237086f1de4e7d68f2d2456fc787bc01')
  else
    Result := TiToken.Create(aClient, '0x7e9997a38a439b2be7ed9c9c4628391d3e055d48');
end;

function iToken(const aClient: IWeb3; const aReserve: TReserve): IResult<IiToken>;
begin
  case aReserve of
    DAI : Result := TResult<IiToken>.Ok(iDAI(aClient));
    USDC: Result := TResult<IiToken>.Ok(iUSDC(aClient));
    USDT: Result := TResult<IiToken>.Ok(iUSDT(aClient));
  else
    Result := TResult<IiToken>.Err(nil, TError.Create('%s not supported', [aReserve.Symbol]));
  end;
end;

{ TFulcrum }

// Approve the iToken contract to move your underlying asset.
class procedure TFulcrum.Approve(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  iToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(iToken: IiToken)
    begin
      iToken.LoanTokenAddress(procedure(address: TAddress; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          web3.eth.erc20.approve(web3.eth.erc20.create(client, address), from, iToken.Contract, amount, callback);
      end);
    end);
end;

class procedure TFulcrum.TokenToUnderlying(
  const client  : IWeb3;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<BigInteger, IError>);
begin
  iToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(iToken: IiToken)
    begin
      iToken.TokenPrice(procedure(price: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(BigInteger.Create(amount.AsDouble * (price.AsDouble / 1e18)), nil);
      end);
    end);
end;

class procedure TFulcrum.UnderlyingToToken(
  const client  : IWeb3;
  const reserve : TReserve;
  const amount  : BIgInteger;
  const callback: TProc<BigInteger, IError>);
begin
  iToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(iToken: IiToken)
    begin
      iToken.TokenPrice(procedure(price: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(BigInteger.Create(amount.AsDouble / (price.AsDouble / 1e18)), nil);
      end);
    end);
end;

class function TFulcrum.Name: string;
begin
  Result := 'Ooki';
end;

class function TFulcrum.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result := (chain = Ethereum) and (reserve in [DAI, USDC, USDT]);
end;

// Returns the annual yield as a percentage with 4 decimals.
class procedure TFulcrum.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  iToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(iToken: IiToken)
    begin
      iToken.SupplyInterestRate(procedure(value: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(BigInteger.Divide(value, BigInteger.Create(1e14)).AsInt64 / 1e4, nil);
      end);
    end);
end;

// Deposits an underlying asset into the lending pool.
class procedure TFulcrum.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  // Before supplying an asset, we must first approve the iToken.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      iToken(client, reserve)
        .ifErr(procedure(err: IError)
        begin
          callback(nil, err)
        end)
        .&else(procedure(iToken: IiToken)
        begin
          iToken.Mint(from, amount, callback)
        end);
  end);
end;

// Returns how much underlying assets you are entitled to.
class procedure TFulcrum.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  iToken(client, reserve)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(iToken: IiToken)
    begin
      // get balance of the underlying asset
      iToken.AssetBalanceOf(owner, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          // get decimals
          iToken.Decimals(procedure(decimals: BigInteger; err: IError)
          begin
            if Assigned(err) or (reserve.Decimals = Power(10, decimals.AsInteger)) then
              callback(balance, err)
            else
              callback(reserve.Scale(balance.AsDouble / Power(10, decimals.AsInteger)), err);
          end);
      end);
    end);
end;

// Redeems your balance of iTokens for the underlying asset.
class procedure TFulcrum.Withdraw(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(owner: TAddress)
    begin
      iToken(client, reserve)
        .ifErr(procedure(err: IError)
        begin
          callback(nil, 0, err)
        end)
        .&else(procedure(iToken: IiToken)
        begin
          // step #1: get the iToken balance
          iToken.BalanceOf(owner, procedure(amount: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(nil, 0, err)
            else
              // step #2: redeem iToken-amount in exchange for the underlying asset
              iToken.Burn(from, amount, procedure(rcpt: ITxReceipt; err: IError)
              begin
                if Assigned(err) then
                  callback(nil, 0, err)
                else
                  TokenToUnderlying(client, reserve, amount, procedure(output: BigInteger; err: IError)
                  begin
                    if Assigned(err) then
                      callback(rcpt, 0, err)
                    else
                      callback(rcpt, output, nil);
                  end);
              end);
          end);
        end);
    end);
end;

class procedure TFulcrum.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  // step #1: from underlying-amount to iToken-amount
  UnderlyingToToken(client, reserve, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(nil, 0, err)
    else
      iToken(client, reserve)
        .ifErr(procedure(err: IError)
        begin
          callback(nil, 0, err)
        end)
        .&else(procedure(iToken: IiToken)
        begin
          // step #2: redeem iToken-amount in exchange for the underlying asset
          iToken.Burn(from, input, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
              callback(nil, 0, err)
            else
              callback(rcpt, amount, err);
          end);
        end);
  end);
end;

{ TiToken }

function TiToken.ListenForLatestBlock: Boolean;
begin
  Result := inherited ListenForLatestBlock or Assigned(FOnMint) or Assigned(FOnBurn);
end;

procedure TiToken.OnLatestBlockMined(log: PLog; err: IError);
begin
  inherited OnLatestBlockMined(log, err);

  if not Assigned(log) then
    EXIT;

  if Assigned(FOnMint) then
    if log^.isEvent('Mint(address,uint256,uint256,uint256)') then
      // emitted upon a successful Mint
      FOnMint(Self,
              log^.Topic[1].toAddress, // minter
              log^.Data[0].toUInt256,  // token amount
              log^.Data[1].toUInt256,  // asset amount
              log^.Data[2].toUInt256); // price

  if Assigned(FOnBurn) then
    if log^.isEvent('Burn(address,uint256,uint256,uint256)') then
      // emitted upon a successful Burn
      FOnBurn(Self,
              log^.Topic[1].toAddress, // burner
              log^.Data[0].toUInt256,  // token amount
              log^.Data[1].toUInt256,  // asset amount
              log^.Data[2].toUInt256); // price
end;

function TiToken.SetOnMint(const Value: TOnMint): IiToken;
begin
  Result := Self;
  FOnMint := Value;
  EventChanged;
end;

function TiToken.SetOnBurn(const Value: TOnBurn): IiToken;
begin
  Result := Self;
  FOnBurn := Value;
  EventChanged;
end;

// Called to redeem owned iTokens for an equivalent amount of the underlying asset, at the current tokenPrice() rate.
// The supplier will receive the asset proceeds.
procedure TiToken.Burn(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(supplier: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'burn(address,uint256)', [supplier, web3.utils.toHex(amount)], callback)
    end);
end;

// Called to deposit assets to the iToken, which in turn mints iTokens to the lender�s wallet at the current tokenPrice() rate.
// A prior ERC20 �approve� transaction should have been sent to the asset token for an amount greater than or equal to the specified amount.
// The supplier will receive the minted iTokens.
procedure TiToken.Mint(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(supplier: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'mint(address,uint256)', [supplier, web3.utils.toHex(amount)], callback)
    end);
end;

// Returns the user's balance of the underlying asset, scaled by 1e18
// This is the same as multiplying the user's token balance by the token price.
procedure TiToken.AssetBalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'assetBalanceOf(address)', [owner], callback);
end;

// Returns the underlying asset contract address for this iToken.
procedure TiToken.LoanTokenAddress(const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'loanTokenAddress()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// Returns the aggregate rate that all lenders are receiving from borrowers, scaled by 1e18
procedure TiToken.SupplyInterestRate(const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'supplyInterestRate()', [], callback);
end;

// Returns the current price of the iToken, scaled by 1e18
procedure TiToken.TokenPrice(const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'tokenPrice()', [], callback);
end;

end.
