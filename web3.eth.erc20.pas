{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.erc20;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth,
  web3.eth.types,
  web3.types;

type
  TERC20 = class
  private
    FClient  : TWeb3;
    FContract: TAddress;
  public
    constructor Create(aClient: TWeb3; aContract: TAddress); virtual;

    //------- read contract ----------------------------------------------------
    procedure Name       (callback: TASyncString);
    procedure Symbol     (callback: TAsyncString);
    procedure Decimals   (callback: TASyncQuantity);
    procedure TotalSupply(callback: TASyncQuantity);
    procedure BalanceOf  (owner: TAddress; callback: TASyncQuantity);
    procedure Allowance  (owner, spender: TAddress; callback: TASyncQuantity);

    //------- write contract ---------------------------------------------------
    procedure Transfer(
      from    : TPrivateKey;
      &to     : TAddress;
      value   : UInt64;
      callback: TASyncTxHash);
    procedure Approve(
      owner   : TPrivateKey;
      spender : TAddress;
      value   : UInt64;
      callback: TASyncTxHash);

    property Client  : TWeb3    read FClient;
    property Contract: TAddress read FContract;
  end;

implementation

{ TERC20 }

constructor TERC20.Create(aClient: TWeb3; aContract: TAddress);
begin
  inherited Create;
  FClient   := aClient;
  FContract := aContract;
end;

procedure TERC20.Name(callback: TASyncString);
begin
  web3.eth.call(Client, Contract, 'name()', [], procedure(tup: TTuple; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC20.Symbol(callback: TASyncString);
begin
  web3.eth.call(Client, Contract, 'symbol()', [], procedure(tup: TTuple; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC20.Decimals(callback: TASyncQuantity);
begin
  web3.eth.call(Client, Contract, 'decimals()', [], callback);
end;

procedure TERC20.TotalSupply(callback: TASyncQuantity);
begin
  web3.eth.call(Client, Contract, 'totalSupply()', [], callback);
end;

procedure TERC20.BalanceOf(owner: TAddress; callback: TASyncQuantity);
begin
  web3.eth.call(Client, Contract, 'balanceOf(address)', [owner], callback);
end;

procedure TERC20.Allowance(owner, spender: TAddress; callback: TASyncQuantity);
begin
  web3.eth.call(Client, Contract, 'allowance(address,address)', [owner, spender], callback);
end;

procedure TERC20.Transfer(
  from    : TPrivateKey;
  &to     : TAddress;
  value   : UInt64;
  callback: TASyncTxHash);
begin
  web3.eth.write(Client, from, Contract, 'transfer(address,uint256)', [&to, value], callback);
end;

procedure TERC20.Approve(
  owner   : TPrivateKey;
  spender : TAddress;
  value   : UInt64;
  callback: TASyncTxHash);
begin
  web3.eth.write(Client, owner, Contract, 'approve(address,uint256)', [spender, value], callback);
end;

end.
