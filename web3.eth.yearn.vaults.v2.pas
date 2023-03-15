{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.yearn.vaults.v2;

{$I web3.inc}

interface

uses
  // Delphi
  System.DateUtils,
  System.Math,
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
  web3.eth.yearn.finance.api,
  web3.utils;

type
  TyVaultV2 = class(TLendingProtocol)
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

  IyVaultRegistry = interface(ICustomContract)
    procedure LatestVault(const reserve: TAddress; const callback: TProc<TAddress, IError>);
  end;

  IyVaultToken = interface(IERC20)
    //------- read from contract -----------------------------------------------
    procedure PricePerShare(const block: string; const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Deposit(const rom: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
  end;

implementation

{------------------------------ TyVaultRegistry -------------------------------}

type
  TyVaultRegistry = class(TCustomContract, IyVaultRegistry)
  public
    procedure LatestVault(const reserve: TAddress; const callback: TProc<TAddress, IError>);
  end;

procedure TyVaultRegistry.LatestVault(const reserve: TAddress; const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'latestVault(address)', [reserve], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure createRegistry(const client: IWeb3; const callback: TProc<IyVaultRegistry, IError>);
begin
  TAddress.Create(client, 'v2.registry.ychad.eth', procedure(address: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TyVaultRegistry.Create(client, address), nil);
  end);
end;

{-------------------------------- TyVaultToken --------------------------------}

type
  TyVaultToken = class(TERC20, IyVaultToken)
  public
    //------- read from contract -----------------------------------------------
    procedure PricePerShare(const block: string; const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Deposit(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
    procedure Withdraw(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
  end;

procedure TyVaultToken.PricePerShare(const block: string; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'pricePerShare()', block, [], callback);
end;

procedure TyVaultToken.Deposit(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'deposit(uint256)', [web3.utils.toHex(amount)], callback);
end;

procedure TyVaultToken.Withdraw(const from: TPrivateKey; const amount: BigInteger; const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'withdraw(uint256)', [web3.utils.toHex(amount)], callback);
end;

procedure createVaultToken(const client: IWeb3; const reserve: TReserve; const callback: TProc<IyVaultToken, IError>);
begin
  reserve.Address(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      // step #1: use the yearn API
      web3.eth.yearn.finance.api.latest(client.Chain, underlying, v2, procedure(vault: IYearnVault; err: IError)
      begin
        if Assigned(vault) then
        begin
          callback(TyVaultToken.Create(client, vault.Address), err);
          EXIT;
        end;
        // step #2; if the yearn API didn't work, use the on-chain registry
        createRegistry(client, procedure(reg: IyVaultRegistry; err: IError)
        begin
          if Assigned(reg) then
          begin
            reg.LatestVault(underlying, procedure(vault: TAddress; err: IError)
            begin
              if Assigned(err) then
                callback(nil, err)
              else
                callback(TyVaultToken.Create(client, vault), err);
            end);
            EXIT;
          end;
          callback(nil, err);
        end);
      end);
    end);
end;

{---------------------------------- helpers -----------------------------------}

procedure pricePerShare(const yToken: IyVaultToken; const block: string; const callback: TProc<Double, IError>);
begin
  yToken.PricePerShare(block, procedure(price: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      yToken.Decimals(procedure(decimals: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(price.AsDouble / Power(10, decimals.AsInteger), nil);
      end);
  end);
end;

procedure vaultTokenToUnderlying(const yToken: IyVaultToken; const amount: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  pricePerShare(yToken, BLOCK_LATEST, procedure(price: Double; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsDouble * price), nil);
  end);
end;

procedure underlyingToVaultToken(const yToken: IyVaultToken; const amount: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  pricePerShare(yToken, BLOCK_LATEST, procedure(price: Double; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(BigInteger.Create(amount.AsDouble / price), nil);
  end);
end;

{--------------------------------- TyVaultV2 ----------------------------------}

class function TyVaultV2.Name: string;
begin
  Result := 'yVault v2';
end;

class function TyVaultV2.Supports(const chain: TChain; const reserve: TReserve): Boolean;
begin
  Result :=
    (chain = Fantom) and (reserve in [DAI, USDC, USDT])
  or
    (chain = Ethereum) and (reserve in [DAI, USDC, USDT, TUSD]);
end;

class procedure TyVaultV2.APY(
  const client   : IWeb3;
  const etherscan: IEtherscan;
  const reserve  : TReserve;
  const period   : TPeriod;
  const callback : TProc<Double, IError>);
begin
  reserve.Address(client.Chain)
    .ifErr(procedure(err: IError)
    begin
      callback(0, err)
    end)
    .&else(procedure(underlying: TAddress)
    begin
      // step #1: use the yearn API
      web3.eth.yearn.finance.api.latest(client.Chain, underlying, v2, procedure(vault: IYearnVault; err: IError)
      begin
        if Assigned(vault) then
        begin
          callback(vault.APY, err);
          EXIT;
        end;
        // step #2; if the yearn API didn't work, use the on-chain smart contract
        createVaultToken(client, reserve, procedure(yToken: IyVaultToken; err: IError)
        begin
          if Assigned(err) then
            callback(0, err)
          else
            yToken.PricePerShare(BLOCK_LATEST, procedure(currPrice: BigInteger; err: IError)
            begin
              if Assigned(err) then
                callback(0, err)
              else
                etherscan.getBlockNumberByTimestamp(web3.Now - period.Seconds, procedure(bn: BigInteger; err: IError)
                begin
                  if Assigned(err) then
                    callback(0, err)
                  else
                    yToken.PricePerShare(web3.utils.toHex(bn), procedure(pastPrice: BigInteger; err: IError)
                    begin
                      if Assigned(err) then
                        callback(0, err)
                      else if IsNaN(currPrice.AsDouble) or IsNaN(pastPrice.AsDouble) then
                        callback(NaN, nil)
                      else
                        callback(period.ToYear((currPrice.AsDouble / pastPrice.AsDouble - 1) * 100), nil);
                    end);
                end);
            end);
        end);
      end);
    end);
end;

class procedure TyVaultV2.Deposit(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  createVaultToken(client, reserve, procedure(yToken: IyVaultToken; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      reserve.Address(client.Chain)
        .ifErr(procedure(err: IError)
        begin
          callback(nil, err)
        end)
        .&else(procedure(underlying: TAddress)
        begin
          web3.eth.erc20.approve(web3.eth.erc20.create(client, underlying), from, yToken.Contract, amount, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
              callback(nil, err)
            else
              yToken.Deposit(from, amount, callback);
          end);
        end);
  end);
end;

class procedure TyVaultV2.Balance(
  const client  : IWeb3;
  const owner   : TAddress;
  const reserve : TReserve;
  const callback: TProc<BigInteger, IError>);
begin
  createVaultToken(client, reserve, procedure(yToken: IyVaultToken; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      // step #1: get the yVaultToken balance
      yToken.BalanceOf(owner, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          // step #2: multiply it by the current yVaultToken price
          vaultTokenToUnderlying(yToken, balance, callback);
      end);
  end);
end;

class procedure TyVaultV2.Withdraw(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  createVaultToken(client, reserve, procedure(yToken: IyVaultToken; err: IError)
  begin
    if Assigned(err) then
      callback(nil, 0, err)
    else
      // step #1: get the yVaultToken balance
      yToken.BalanceOf(from, procedure(balance: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          // step #2: withdraw yVaultToken-amount in exchange for the underlying asset.
          yToken.Withdraw(from, balance, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
              callback(nil, 0, err)
            else
              // step #3: from yVaultToken-balance to underlying-balance
              vaultTokenToUnderlying(yToken, balance, procedure(output: BigInteger; err: IError)
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

class procedure TyVaultV2.WithdrawEx(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const reserve : TReserve;
  const amount  : BigInteger;
  const callback: TProc<ITxReceipt, BigInteger, IError>);
begin
  createVaultToken(client, reserve, procedure(yToken: IyVaultToken; err: IError)
  begin
    if Assigned(err) then
      callback(nil, 0, err)
    else
      // step #1: from underlying-amount to yVaultToken-amount
      underlyingToVaultToken(yToken, amount, procedure(input: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          // step #2: withdraw yVaultToken-amount in exchange for the underlying asset.
          yToken.Withdraw(from, input, procedure(rcpt: ITxReceipt; err: IError)
          begin
            if Assigned(err) then
              callback(nil, 0, err)
            else
              callback(rcpt, amount, nil);
          end);
      end);
  end);
end;

end.
