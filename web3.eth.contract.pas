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
  web3,
  web3.eth.types;

type
  TCustomContract = class abstract(TInterfacedObject)
  strict private
    FClient  : TWeb3;
    FContract: TAddress;
  public
    constructor Create(aClient: TWeb3; aContract: TAddress); virtual;
    property Client  : TWeb3    read FClient;
    property Contract: TAddress read FContract;
  end;

implementation

{ TCustomContract }

constructor TCustomContract.Create(aClient: TWeb3; aContract: TAddress);
begin
  inherited Create;
  FClient   := aClient;
  FContract := aContract;
end;

end.
