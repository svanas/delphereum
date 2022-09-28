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

unit web3.eth.yearn.finance;

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
      client  : IWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
    class procedure BalanceOf(
      client  : IWeb3;
      yToken  : TyTokenClass;
      owner   : TAddress;
      callback: TProc<BigInteger, IError>);
    class procedure TokenToUnderlying(
      client  : IWeb3;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TProc<BigInteger, IError>);
    class procedure UnderlyingToToken(
      client  : IWeb3;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TProc<BigInteger, IError>);
  strict protected
    class procedure _APY(
      client  : IWeb3;
      yToken  : TyTokenClass;
      period  : TPeriod;
      callback: TProc<Double, IError>);
    class procedure _Deposit(
      client  : IWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, IError>);
    class procedure _Balance(
      client  : IWeb3;
      owner   : TAddress;
      yToken  : TyTokenClass;
      callback: TProc<BigInteger, IError>);
    class procedure _Withdraw(
      client  : IWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      callback: TProc<ITxReceipt, BigInteger, IError>);
    class procedure _WithdrawEx(
      client  : IWeb3;
      from    : TPrivateKey;
      yToken  : TyTokenClass;
      amount  : BigInteger;
      callback: TProc<ITxReceipt, BigInteger, IError>);
  end;

  TyToken = class abstract(TERC20)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    //------- read from contract -----------------------------------------------
    procedure Token(callback: TProc<TAddress, IError>);
    procedure GetPricePerFullShare(const block: string; callback: TProc<BigInteger, IError>);
    //------- helpers ----------------------------------------------------------
    class function DeployedAt: TAddress; virtual; abstract;
    procedure ApproveUnderlying(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
    procedure TokenToUnderlying(amount: BigInteger; callback: TProc<BigInteger, IError>);
    procedure UnderlyingToToken(amount: BigInteger; callback: TProc<BigInteger, IError>);
    procedure APY(period: TPeriod; callback: TProc<Double, IError>);
    //------- write to contract ------------------------------------------------
    procedure Deposit(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
  end;

implementation

{ TyEarnCustom }

class procedure TyEarnCustom.Approve(
  client  : IWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  const token = yToken.Create(client);
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
  client  : IWeb3;
  yToken  : TyTokenClass;
  owner   : TAddress;
  callback: TProc<BigInteger, IError>);
begin
  const token = yToken.Create(client);
  try
    token.BalanceOf(owner, callback);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom.TokenToUnderlying(
  client  : IWeb3;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TProc<BigInteger, IError>);
begin
  const token = yToken.Create(client);
  try
    token.TokenToUnderlying(amount, callback);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom.UnderlyingToToken(
  client  : IWeb3;
  yToken  : TyTokenClass;
  amount  : BIgInteger;
  callback: TProc<BigInteger, IError>);
begin
  const token = yToken.Create(client);
  try
    token.UnderlyingToToken(amount, callback);
  finally
    token.Free;
  end;
end;

class procedure TyEarnCustom._APY(
  client  : IWeb3;
  yToken  : TyTokenClass;
  period  : TPeriod;
  callback: TProc<Double, IError>);
begin
  const token = yToken.Create(client);
  if Assigned(token) then
  begin
    token.APY(period, procedure(apy: Double; err: IError)
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
  client  : IWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, IError>);
begin
  Self.Approve(client, from, yToken, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const token = yToken.Create(client);
    try
      token.Deposit(from, amount, callback);
    finally
      token.Free;
    end;
  end);
end;

class procedure TyEarnCustom._Balance(
  client  : IWeb3;
  owner   : TAddress;
  yToken  : TyTokenClass;
  callback: TProc<BigInteger, IError>);
begin
  const token = yToken.Create(client);
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
  client  : IWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  callback: TProc<ITxReceipt, BigInteger, IError>);
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
          const token = yToken.Create(client);
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
  client  : IWeb3;
  from    : TPrivateKey;
  yToken  : TyTokenClass;
  amount  : BigInteger;
  callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  // step #1: from Underlying-amount to yToken-amount
  Self.UnderlyingToToken(client, yToken, amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, 0, err);
      EXIT;
    end;
    const token = yToken.Create(client);
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

constructor TyToken.Create(aClient: IWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

// Returns the underlying asset contract address for this yToken.
procedure TyToken.Token(callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'token()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

// Current yToken price, in underlying (eg. DAI) terms.
procedure TyToken.GetPricePerFullShare(const block: string; callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'getPricePerFullShare()', block, [], callback);
end;

procedure TyToken.ApproveUnderlying(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  Self.Token(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const erc20 = TERC20.Create(client, addr);
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

procedure TyToken.TokenToUnderlying(amount: BigInteger; callback: TProc<BigInteger, IError>);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsDouble * (price.AsDouble / 1e18)), nil);
  end);
end;

procedure TyToken.UnderlyingToToken(amount: BIgInteger; callback: TProc<BigInteger, IError>);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsDouble / (price.AsDouble / 1e18)), nil);
  end);
end;

procedure TyToken.APY(period: TPeriod; callback: TProc<Double, IError>);
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
        callback(period.ToYear(currPrice.AsDouble / pastPrice.AsDouble - 1) * 100, nil);
      end);
    end);
  end);
end;

procedure TyToken.Deposit(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'deposit(uint256)', [web3.utils.toHex(amount)], callback);
end;

procedure TyToken.Withdraw(from: TPrivateKey; amount: BigInteger; callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'withdraw(uint256)', [web3.utils.toHex(amount)], callback);
end;

end.
