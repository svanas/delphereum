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
{******************************************************************************}

unit web3.eth.idle.finance.v4;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
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
  TIdle = class(TLendingProtocol)
  protected
    class procedure Approve(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
    class procedure IdleToUnderlying(
      client  : IWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<BigInteger, IError>);
    class procedure UnderlyingToIdle(
      client  : IWeb3;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<BigInteger, IError>);
  public
    class function Name: string; override;
    class function Supports(
      chain  : TChain;
      reserve: TReserve): Boolean; override;
    class procedure APY(
      client    : IWeb3;
      _etherscan: IEtherscan;
      reserve   : TReserve;
      _period   : TPeriod;
      callback  : TProc<Double, IError>); override;
    class procedure Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>); override;
    class procedure Balance(
      client  : IWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TProc<BigInteger, IError>); override;
    class procedure Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TProc<ITxReceipt, BigInteger, IError>); override;
    class procedure WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, BigInteger, IError>); override;
  end;

  TIdleViewHelper = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure GetFullAPR(idleToken: TAddress; callback: TProc<BigInteger, IError>);
  end;

  TIdleToken = class abstract(TERC20)
  public
    constructor Create(aClient: IWeb3); reintroduce; overload; virtual; abstract;
    procedure Token(callback: TProc<TAddress, IError>);
    procedure GetAvgAPR(callback: TProc<BigInteger, IError>);
    procedure GetFullAPR(callback: TProc<BigInteger, IError>);
    procedure TokenPrice(callback: TProc<BigInteger, IError>);
    procedure MintIdleToken(
      from              : TPrivateKey; // supplier of the underlying asset, and receiver of IdleTokens
      amount            : BigInteger;  // amount of underlying asset to be lent
      skipWholeRebalance: Boolean;     // triggers a rebalance of the whole pools if true
      referral          : TAddress;    // address for eventual future referral program
      callback          : TProc<ITxReceipt, IError>);
    procedure RedeemIdleToken(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
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

  TIdleTUSD = class(TIdleToken)
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
    TIdleTUSD,
    nil
  );

{ TIdle }

class procedure TIdle.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const IdleToken = IdleTokenClass[reserve].Create(client);
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
        web3.eth.erc20.approve(web3.eth.erc20.create(client, addr), from, IdleToken.Contract, amount, callback)
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
  callback: TProc<BigInteger, IError>);
begin
  const IdleToken = IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  try
    IdleToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(reserve.Scale(reserve.Unscale(amount) * (price.AsDouble / 1e18)), nil);
    end);
  finally
    IdleToken.free;
  end;
end;

class procedure TIdle.UnderlyingToIdle(
  client  : IWeb3;
  reserve : TReserve;
  amount  : BIgInteger;
  callback: TProc<BigInteger, IError>);
begin
  const IdleToken = IdleTokenClass[reserve].Create(client);
  if Assigned(IdleToken) then
  try
    IdleToken.TokenPrice(procedure(price: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(reserve.Scale(reserve.Unscale(amount) / (price.AsDouble / 1e18)), nil);
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
  Result := (chain = Ethereum) and (reserve in [USDT, TUSD, DAI, USDC]);
end;

class procedure TIdle.APY(
  client    : IWeb3;
  _etherscan: IEtherscan;
  reserve   : TReserve;
  _period   : TPeriod;
  callback  : TProc<Double, IError>);
begin
  const IdleToken = IdleTokenClass[reserve].Create(client);
  IdleToken.GetFullAPR(procedure(apr1: BigInteger; err1: IError)
  begin
    if Assigned(err1) then
    begin
      IdleToken.GetAvgAPR(procedure(apr2: BigInteger; err2: IError)
      begin
        if Assigned(err2) then
          callback(0, err2)
        else
          callback(apr2.AsDouble / 1e18, nil);
      end);
      EXIT;
    end;
    callback(apr1.AsDouble / 1e18, nil);
  end);
end;

class procedure TIdle.Deposit(
  client  : IWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const IdleToken = IdleTokenClass[reserve].Create(client);
    if Assigned(IdleToken) then
    try
      IdleToken.MintIdleToken(from, amount, True, EMPTY_ADDRESS, callback);
    finally
      IdleToken.Free;
    end;
  end);
end;

class procedure TIdle.Balance(
  client  : IWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TProc<BigInteger, IError>);
begin
  const IdleToken = IdleTokenClass[reserve].Create(client);
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
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  const IdleToken = IdleTokenClass[reserve].Create(client);
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
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  // step #1: from Underlying-amount to IdleToken-amount
  UnderlyingToIdle(client, reserve, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    const IdleToken = IdleTokenClass[reserve].Create(client);
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

procedure TIdleViewHelper.GetFullAPR(idleToken: TAddress; callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'getFullAPR(address)', [idleToken], callback);
end;

{ TIdleToken }

// Returns the underlying asset contract address for this IdleToken.
procedure TIdleToken.Token(callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'token()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// Get base layer aggregated APR of IdleToken.
// This does not take into account fees, unlent percentage and additional APR given by governance tokens.
procedure TIdleToken.GetAvgAPR(callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'getAvgAPR()', [], callback);
end;

// Get current IdleToken average APR considering governance tokens.
procedure TIdleToken.GetFullAPR(callback: TProc<BigInteger, IError>);
begin
  const helper = TIdleViewHelper.Create(Self.Client);
  try
    helper.GetFullAPR(Self.Contract, callback);
  finally
    helper.Free;
  end;
end;

// Current IdleToken price, in underlying (eg. DAI) terms.
procedure TIdleToken.TokenPrice(callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'tokenPrice()', [], callback);
end;

// Transfers the amount of underlying assets to IdleToken contract and then mints interest-bearing tokens with that amount.
procedure TIdleToken.MintIdleToken(
  from              : TPrivateKey; // supplier of the underlying asset, and receiver of IdleTokens
  amount            : BigInteger;  // amount of underlying asset to be lent
  skipWholeRebalance: Boolean;     // triggers a rebalance of the whole pools if true
  referral          : TAddress;    // address for eventual future referral program
  callback          : TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract,
    'mintIdleToken(uint256,bool,address)',
    [web3.utils.toHex(amount), skipWholeRebalance, referral], callback);
end;

// Redeems your underlying balance by burning your IdleTokens.
procedure TIdleToken.RedeemIdleToken(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract,
    'redeemIdleToken(uint256)', [web3.utils.toHex(amount)], callback);
end;

{ TIdleDAI }

constructor TIdleDAI.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0x3fe7940616e5bc47b0775a0dccf6237893353bb4');
end;

{ TIdleUSDC }

constructor TIdleUSDC.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0x5274891bEC421B39D23760c04A6755eCB444797C');
end;

{ TIdleUSDT }

constructor TIdleUSDT.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0xF34842d05A1c888Ca02769A633DF37177415C2f8');
end;

{ TIdleTUSD }

constructor TIdleTUSD.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0xc278041fDD8249FE4c1Aad1193876857EEa3D68c');
end;

end.
