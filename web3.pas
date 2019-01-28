{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils;

type
  TChain = (
    Mainnet,
    Ropsten,
    Rinkeby,
    Kovan,
    Ganache
  );

const
  chainId: array[TChain] of Integer = (
    1,   // Mainnet
    3,   // Ropsten
    4,   // Rinkeby
    42,  // Kovan
    1    // Ganache
  );

type
  EWeb3 = class(Exception);

type
  TWeb3 = record
    var
      URL  : string;
      Chain: TChain;
    class function New(const aURL: string): TWeb3; overload; static;
    class function New(const aURL: string; aChain: TChain): TWeb3; overload; static;
  end;

implementation

class function TWeb3.New(const aURL: string): TWeb3;
begin
  Result := New(aURL, Mainnet);
end;

class function TWeb3.New(const aURL: string; aChain: TChain): TWeb3;
begin
  Result.URL   := aURL;
  Result.Chain := aChain;
end;

end.
