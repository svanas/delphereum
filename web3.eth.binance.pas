{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.binance;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  EBinance = class(EWeb3);

function endpoint(chain: TChain): string;

implementation

uses
  // Delphi
  System.TypInfo;

function endpoint(chain: TChain): string;
begin
  if chain = BinanceSmartChain then
    Result := 'https://bsc-dataseed.binance.org/'
  else if chain = BinanceSmartChainTestNet then
    Result := 'https://data-seed-prebsc-1-s1.binance.org:8545/'
  else
    raise EBinance.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))]);
end;

end.
