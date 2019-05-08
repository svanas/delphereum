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
  System.Threading,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.logs,
  web3.eth.types,
  web3.types;

type
  TOnTransfer = reference to procedure(
    Sender: TObject;
    From  : TAddress;
    &To   : TAddress;
    Value : UInt64);
  TOnApproval = reference to procedure(
    Sender : TObject;
    Owner  : TAddress;
    Spender: TAddress;
    Value  : UInt64);

  TERC20 = class(TCustomContract)
  strict private
    FTask      : ITask;
    FOnTransfer: TOnTransfer;
    FOnApproval: TOnApproval;
    procedure SetOnTransfer(Value: TOnTransfer);
    procedure SetOnApproval(Value: TOnApproval);
  protected
    procedure WatchOrStop; virtual;
  public
    constructor Create(aClient: TWeb3; aContract: TAddress); override;
    destructor  Destroy; override;

    //------- read contract ----------------------------------------------------
    procedure Name       (callback: TASyncString);
    procedure Symbol     (callback: TASyncString);
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

    //------- events -----------------------------------------------------------
    property OnTransfer: TOnTransfer read FOnTransfer write SetOnTransfer;
    property OnApproval: TOnApproval read FOnApproval write SetOnApproval;
  end;

implementation

{ TERC20 }

constructor TERC20.Create(aClient: TWeb3; aContract: TAddress);
begin
  inherited Create(aClient, aContract);

  FTask := web3.eth.logs.get(aClient, aContract,
    procedure(log: TLog)
    begin
      if Assigned(FOnTransfer) then
        if log.isEvent('Transfer(address,address,uint256)') then
          FOnTransfer(Self,
                      TAddress.New(log.Topic[1]),
                      TAddress.New(log.Topic[2]),
                      toInt(log.Data[0]));
      if Assigned(FOnApproval) then
        if log.isEvent('Approval(address,address,uint256)') then
          FOnApproval(Self,
                      TAddress.New(log.Topic[1]),
                      TAddress.New(log.Topic[2]),
                      toInt(log.Data[0]));
    end);
end;

destructor TERC20.Destroy;
begin
  if FTask.Status = TTaskStatus.Running then
    FTask.Cancel;
  inherited Destroy;
end;

procedure TERC20.SetOnTransfer(Value: TOnTransfer);
begin
  FOnTransfer := Value;
  WatchOrStop;
end;

procedure TERC20.SetOnApproval(Value: TOnApproval);
begin
  FOnApproval := Value;
  WatchOrStop;
end;

procedure TERC20.WatchOrStop;
begin
  if Assigned(FOnTransfer)
  or Assigned(FOnApproval) then
  begin
    if FTask.Status <> TTaskStatus.Running then
      FTask.Start;
    EXIT;
  end;
  if FTask.Status = TTaskStatus.Running then
    FTask.Cancel;
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
