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
  System.DateUtils,
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
  IyToken = interface(IERC20)
    //------- read from contract -----------------------------------------------
    procedure Token(const callback: TProc<TAddress, IError>);
    procedure GetPricePerFullShare(const block: string; const callback: TProc<BigInteger, IError>);
    //------- helpers ----------------------------------------------------------
    procedure TokenToUnderlying(const amount: BigInteger; const callback: TProc<BigInteger, IError>);
    procedure UnderlyingToToken(const amount: BigInteger; const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Deposit(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
  end;

  TCustomYearn = class abstract(TLendingProtocol)
  protected
    class procedure yAPY(
      const yToken   : IyToken;
      const etherscan: IEtherscan;
      const period   : TPeriod;
      const callback : TProc<Double, IError>);
    class procedure yDeposit(
      const client  : IWeb3;
      const yToken  : IyToken;
      const from    : TPrivateKey;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    class procedure yBalance(
      const yToken  : IyToken;
      const owner   : TAddress;
      const callback: TProc<BigInteger, IError>);
    class procedure yWithdraw(
      const yToken  : IyToken;
      const from    : TPrivateKey;
      const callback: TProc<ITxReceipt, BigInteger, IError>); overload;
    class procedure yWithdraw(
      const yToken  : IyToken;
      const from    : TPrivateKey;
      const amount  : BigInteger;
      const callback: TProc<ITxReceipt, BigInteger, IError>); overload;
  end;

  TyToken = class(TERC20, IyToken)
  public
    //------- read from contract -----------------------------------------------
    procedure Token(const callback: TProc<TAddress, IError>);
    procedure GetPricePerFullShare(const block: string; const callback: TProc<BigInteger, IError>);
    //------- helpers ----------------------------------------------------------
    procedure TokenToUnderlying(const amount: BigInteger; const callback: TProc<BigInteger, IError>);
    procedure UnderlyingToToken(const amount: BigInteger; const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Deposit(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
  end;

implementation

{ TCustomYearn }

class procedure TCustomYearn.yAPY(
  const yToken   : IyToken;
  const etherscan: IEtherscan;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  yToken.GetPricePerFullShare(BLOCK_LATEST, procedure(currPrice: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      etherscan.getBlockNumberByTimestamp(web3.Now - period.Seconds, procedure(bn: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          yToken.GetPricePerFullShare(web3.utils.toHex(bn), procedure(pastPrice: BigInteger; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(period.ToYear(currPrice.AsDouble / pastPrice.AsDouble - 1) * 100, nil);
          end);
      end);
  end);
end;

class procedure TCustomYearn.yDeposit(
  const client  : IWeb3;
  const yToken  : IyToken;
  const from    : TPrivateKey;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  yToken.Token(procedure(address: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.erc20.approve(web3.eth.erc20.create(client, address), from, yToken.Contract, amount, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          yToken.Deposit(from, amount, callback);
      end);
  end);
end;

class procedure TCustomYearn.yBalance(
  const yToken  : IyToken;
  const owner   : TAddress;
  const callback: TProc<BigInteger, IError>);
begin
  // step #1: get the yToken balance
  yToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      // step #2: multiply it by the current yToken price
      yToken.TokenToUnderlying(balance, procedure(output: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(output, nil);
      end);
  end);
end;

class procedure TCustomYearn.yWithdraw(
  const yToken  : IyToken;
  const from    : TPrivateKey;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, 0, err)
    end)
    .&else(procedure(owner: TAddress)
    begin
      // step #1: get the yToken balance
      yToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) or (balance = 0) then
          callback(nil, 0, err)
        else
          // step #2: withdraw yToken-amount in exchange for the underlying asset.
          yToken.Withdraw(from, balance, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
              callback(nil, 0, err)
            else
              // step #3: from yToken-balance to underlying-balance
              yToken.TokenToUnderlying(balance, procedure(output: BigInteger; err: IError)
              begin
                if Assigned(err) then
                  callback(rcpt, 0, err)
                else
                  callback(rcpt, output, nil);
              end);
          end);
      end);
    end);
end;

class procedure TCustomYearn.yWithdraw(
  const yToken  : IyToken;
  const from    : TPrivateKey;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  // step #1: from underlying-amount to yToken-amount
  yToken.UnderlyingToToken(amount, procedure(input: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(nil, 0, err)
    else
      // step #2: withdraw yToken-amount in exchange for the underlying asset.
      yToken.Withdraw(from, input, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          callback(rcpt, amount, nil);
      end);
  end);
end;

{ TyToken }

// Returns the underlying asset contract address for this yToken.
procedure TyToken.Token(const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'token()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// Current yToken price, in underlying (eg. DAI) terms.
procedure TyToken.GetPricePerFullShare(const block: string; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'getPricePerFullShare()', block, [], callback);
end;

procedure TyToken.TokenToUnderlying(const amount: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsDouble * (price.AsDouble / 1e18)), nil);
  end);
end;

procedure TyToken.UnderlyingToToken(const amount: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  Self.GetPricePerFullShare(BLOCK_LATEST, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsDouble / (price.AsDouble / 1e18)), nil);
  end);
end;

procedure TyToken.Deposit(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'deposit(uint256)', [web3.utils.toHex(amount)], callback);
end;

procedure TyToken.Withdraw(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'withdraw(uint256)', [web3.utils.toHex(amount)], callback);
end;

end.
