{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.erc20;

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
  web3.eth.logs,
  web3.eth.types,
  web3.utils;

type
  TOnTransfer = reference to procedure(
    Sender: TObject;
    From  : TAddress;
    &To   : TAddress;
    Value : BigInteger);
  TOnApproval = reference to procedure(
    Sender : TObject;
    Owner  : TAddress;
    Spender: TAddress;
    Value  : BigInteger);

  IERC20 = interface(ICustomContract)
    //------- read from contract -----------------------------------------------
    procedure Name       (const callback: TProc<string, IError>);
    procedure Symbol     (const callback: TProc<string, IError>);
    procedure Decimals   (const callback: TProc<BigInteger, IError>);
    procedure TotalSupply(const callback: TProc<BigInteger, IError>);
    procedure BalanceOf  (const owner: TAddress; const callback: TProc<BigInteger, IError>);
    procedure Allowance  (const owner, spender: TAddress; const callback: TProc<BigInteger, IError>);
    //------- write to contract ------------------------------------------------
    procedure Transfer(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const value   : BigInteger;
      const callback: TProc<TTxHash, IError>);
    procedure TransferEx(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const value   : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure Approve(
      const owner   : TPrivateKey;
      const spender : TAddress;
      const value   : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
  end;

  TERC20 = class(TCustomContract, IERC20)
  strict private
    FLogger    : ILogger;
    FOnTransfer: TOnTransfer;
    FOnApproval: TOnApproval;
    procedure SetOnTransfer(const Value: TOnTransfer);
    procedure SetOnApproval(const Value: TOnApproval);
  protected
    procedure EventChanged;
    function  ListenForLatestBlock: Boolean; virtual;
    procedure OnLatestBlockMined(log: PLog; err: IError); virtual;
  public
    constructor Create(const aClient: IWeb3; const aContract: TAddress); override;
    destructor  Destroy; override;

    //------- read from contract -----------------------------------------------
    procedure Name       (const callback: TProc<string, IError>);
    procedure Symbol     (const callback: TProc<string, IError>);
    procedure Decimals   (const callback: TProc<BigInteger, IError>);
    procedure TotalSupply(const callback: TProc<BigInteger, IError>); overload;
    procedure TotalSupply(const block: string; const callback: TProc<BigInteger, IError>); overload;
    procedure BalanceOf  (const owner: TAddress; const callback: TProc<BigInteger, IError>);
    procedure Allowance  (const owner, spender: TAddress; const callback: TProc<BigInteger, IError>);

    //------- helpers ----------------------------------------------------------
    procedure Scale  (const amount: Double; const callback: TProc<BigInteger, IError>);
    procedure Unscale(const amount: BigInteger; const callback: TProc<Double, IError>);

    //------- write to contract ------------------------------------------------
    procedure Transfer(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const value   : BigInteger;
      const callback: TProc<TTxHash, IError>);
    procedure TransferEx(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const value   : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure Approve(
      const owner   : TPrivateKey;
      const spender : TAddress;
      const value   : BigInteger;
      const callback: TProc<ITxReceipt, IError>);

    //------- events -----------------------------------------------------------
    property OnTransfer: TOnTransfer read FOnTransfer write SetOnTransfer;
    property OnApproval: TOnApproval read FOnApproval write SetOnApproval;
  end;

function create(const client: IWeb3; const contract: TAddress): IERC20;

procedure approve(
  const token   : IERC20;
  const owner   : TPrivateKey;
  const spender : TAddress;
  const value   : BigInteger;
  const callback: TProc<ITxReceipt, IError>);

implementation

function create(const client: IWeb3; const contract: TAddress): IERC20;
begin
  Result := TERC20.Create(client, contract);
end;

procedure approve(
  const token   : IERC20;
  const owner   : TPrivateKey;
  const spender : TAddress;
  const value   : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(address: TAddress)
    begin
      token.Allowance(address, spender, procedure(approved: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          if ((value = 0) and (approved = 0))
          or ((value > 0) and (approved >= value)) then
            callback(nil, nil)
          else
            token.Approve(owner, spender, value, callback);
      end);
    end);
end;

{ TERC20 }

constructor TERC20.Create(const aClient: IWeb3; const aContract: TAddress);
begin
  inherited Create(aClient, aContract);
  FLogger := web3.eth.logs.get(aClient, aContract, OnLatestBlockMined);
end;

destructor TERC20.Destroy;
begin
  if FLogger.Status in [Running, Paused] then FLogger.Stop;
  inherited Destroy;
end;

procedure TERC20.EventChanged;
begin
  if ListenForLatestBlock then
  begin
    if FLogger.Status in [Idle, Paused] then FLogger.Start;
    EXIT;
  end;
  if FLogger.Status = Running then FLogger.Pause;
end;

function TERC20.ListenForLatestBlock: Boolean;
begin
  Result := Assigned(FOnTransfer) or Assigned(FOnApproval);
end;

procedure TERC20.OnLatestBlockMined(log: PLog; err: IError);
begin
  if not Assigned(log) then
    EXIT;

  if Assigned(FOnTransfer) then
    if log^.isEvent('Transfer(address,address,uint256)') then
      FOnTransfer(Self,
                  log^.Topic[1].toAddress, // from
                  log^.Topic[2].toAddress, // to
                  log^.Data[0].toUInt256); // value

  if Assigned(FOnApproval) then
    if log^.isEvent('Approval(address,address,uint256)') then
      FOnApproval(Self,
                  log^.Topic[1].toAddress, // owner
                  log^.Topic[2].toAddress, // spender
                  log^.Data[0].toUInt256); // value
end;

procedure TERC20.SetOnTransfer(const Value: TOnTransfer);
begin
  FOnTransfer := Value;
  EventChanged;
end;

procedure TERC20.SetOnApproval(const Value: TOnApproval);
begin
  FOnApproval := Value;
  EventChanged;
end;

procedure TERC20.Name(const callback: TProc<string, IError>);
begin
  web3.eth.call(Client, Contract, 'name()', [], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC20.Symbol(const callback: TProc<string, IError>);
begin
  web3.eth.call(Client, Contract, 'symbol()', [], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC20.Decimals(const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'decimals()', [], callback);
end;

procedure TERC20.TotalSupply(const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'totalSupply()', [], callback);
end;

procedure TERC20.TotalSupply(const block: string; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'totalSupply()', block, [], callback);
end;

procedure TERC20.BalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'balanceOf(address)', [owner], callback);
end;

procedure TERC20.Allowance(const owner, spender: TAddress; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'allowance(address,address)', [owner, spender], callback);
end;

procedure TERC20.Scale(const amount: Double; const callback: TProc<BigInteger, IError>);
begin
  Self.Decimals(procedure(dec: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      if dec.IsZero then
        callback(BigInteger.Create(amount), nil)
      else
        callback(web3.utils.scale(amount, dec.AsInteger), nil);
  end);
end;

procedure TERC20.Unscale(const amount: BigInteger; const callback: TProc<Double, IError>);
begin
  Self.Decimals(procedure(dec: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      if dec.IsZero then
        callback(amount.AsDouble, nil)
      else
        callback(web3.utils.unscale(amount, dec.AsInteger), nil);
  end);
end;

procedure TERC20.Transfer(
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : BigInteger;
  const callback: TProc<TTxHash, IError>);
begin
  web3.eth.write(Client, from, Contract, 'transfer(address,uint256)', [&to, web3.utils.toHex(value)], callback);
end;

procedure TERC20.TransferEx(
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, from, Contract, 'transfer(address,uint256)', [&to, web3.utils.toHex(value)], callback);
end;

procedure TERC20.Approve(
  const owner   : TPrivateKey;
  const spender : TAddress;
  const value   : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, owner, Contract, 'approve(address,uint256)', [spender, web3.utils.toHex(value)], callback);
end;

end.
