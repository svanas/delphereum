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

unit web3.eth.defi;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3;
  web3,
  web3.eth.types;

type
  TReserve = (DAI, USDC);

type
  TLendingProtocol = class abstract
  protected
    // Returns the ERC-20 contract address of the underlying asset.
    class procedure GetERC20(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncAddress);
  public
    // Returns the annual yield as a percentage with 4 decimals.
    class procedure APY(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncFloat); virtual; abstract;
    // Deposits an underlying asset into the lending pool.
    class procedure Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); virtual; abstract;
  end;

implementation

uses
  // Delphi
  System.TypInfo;

const
  ERC20: array[TReserve] of array[TChain] of TAddress = (
    ( // DAI
      '0x6b175474e89094c44da98b954eedeac495271d0f',  // Mainnet
      '0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108',  // Ropsten
      '',                                            // Rinkeby
      '',                                            // Goerli
      '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD',  // Kovan
      '0x6b175474e89094c44da98b954eedeac495271d0f'), // Ganache
    ( // USDC
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',  // Mainnet
      '0x851dEf71f0e6A903375C1e536Bd9ff1684BAD802',  // Ropsten
      '',                                            // Rinkeby
      '',                                            // Goerli
      '0xe22da380ee6B445bb8273C81944ADEB6E8450422',  // Kovan
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48')  // Ganache
  );

// Returns the ERC-20 contract address of the underlying asset.
class procedure TLendingProtocol.GetERC20(client: TWeb3; reserve: TReserve; callback: TAsyncAddress);
var
  addr: TAddress;
begin
  addr := ERC20[reserve][client.Chain];
  if addr <> '' then
    callback(addr, nil)
  else
    callback('',
      TError.Create('%s is not supported on %s', [
        GetEnumName(TypeInfo(TReserve), Ord(reserve)),
        GetEnumName(TypeInfo(TChain), Ord(client.Chain))
      ])
    );
end;

end.
