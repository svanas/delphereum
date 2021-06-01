{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.chi;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.erc20,
  web3.eth.gas,
  web3.eth.types,
  web3.utils;

type
  TGasToken = class abstract(TERC20)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    // Address on mainnet where this token is deployed
    class function DeployedAt: TAddress; virtual; abstract;
    // Estimate the number of gas units needed for Mint
    procedure Mint(from: TAddress; amount: BigInteger; callback: TAsyncQuantity); overload;
    // Mint gas tokens
    procedure Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt); overload;
  end;

  TGasTokenClass = class of TGasToken;

  TGST1 = class(TGasToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TGST2 = class(TGasToken)
  public
    class function DeployedAt: TAddress; override;
  end;

  TCHI = class(TGasToken)
  public
    class function DeployedAt: TAddress; override;
  end;

implementation

{ TGasToken }

constructor TGasToken.Create(aClient: IWeb3);
begin
  inherited Create(aClient, Self.DeployedAt);
end;

// Estimate the number of gas units needed for Mint
procedure TGasToken.Mint(from: TAddress; amount: BigInteger; callback: TAsyncQuantity);
begin
  estimateGas(
    Self.Client, from, Self.Contract,
    'mint(uint256)', [web3.utils.toHex(amount)], 0, callback);
end;

// Mint gas tokens
procedure TGasToken.Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(
    Self.Client, from, Self.Contract,
    'mint(uint256)', [web3.utils.toHex(amount)], 5200000, callback);
end;

{ TGST1 }

class function TGST1.DeployedAt: TAddress;
begin
  Result := TAddress('0x88d60255F917e3eb94eaE199d827DAd837fac4cB');
end;

{ TGST2 }

class function TGST2.DeployedAt: TAddress;
begin
  Result := TAddress('0x0000000000b3F879cb30FE243b4Dfee438691c04');
end;

{ TCHI }

class function TCHI.DeployedAt: TAddress;
begin
  Result := TAddress('0x0000000000004946c0e9F43F4Dee607b0eF1fA1c');
end;

end.
