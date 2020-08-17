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
  TChi = class(TERC20)
  public
    constructor Create(aClient: TWeb3); reintroduce;
    // Estimate the number of gas units needed for Mint
    procedure Mint(from: TAddress; amount: BigInteger; callback: TAsyncQuantity); overload;
    // Mint Chi tokens
    procedure Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt); overload;
  end;

implementation

constructor TChi.Create(aClient: TWeb3);
begin
  inherited Create(aClient, '0x0000000000004946c0e9F43F4Dee607b0eF1fA1c');
end;

// Estimate the number of gas units needed for Mint
procedure TChi.Mint(from: TAddress; amount: BigInteger; callback: TAsyncQuantity);
begin
  estimateGas(Client, from, Contract,
              'mint(uint256)', [web3.utils.toHex(amount)], 0, callback);
end;

// Mint Chi tokens
procedure TChi.Mint(from: TPrivateKey; amount: BigInteger; callback: TAsyncReceipt);
begin
  web3.eth.write(Client, from, Contract,
                 'mint(uint256)', [web3.utils.toHex(amount)], 5200000, callback);
end;

end.
