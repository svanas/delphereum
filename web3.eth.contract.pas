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

unit web3.eth.contract;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  ICustomContract = interface
    function Client  : IWeb3;
    function Contract: TAddress;
  end;

  TCustomContract = class abstract(TInterfacedObject, ICustomContract)
  strict private
    FClient  : IWeb3;
    FContract: TAddress;
  public
    constructor Create(aClient: IWeb3; aContract: TAddress); virtual;
    function Client  : IWeb3;
    function Contract: TAddress;
  end;

implementation

{ TCustomContract }

constructor TCustomContract.Create(aClient: IWeb3; aContract: TAddress);
begin
  inherited Create;
  FClient   := aClient;
  FContract := aContract;
end;

function TCustomContract.Client: IWeb3;
begin
  Result := FClient;
end;

function TCustomContract.Contract: TAddress;
begin
  Result := FContract;
end;

end.
