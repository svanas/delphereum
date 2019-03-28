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
    Goerli,
    Kovan,
    Ganache
  );

const
  chainId: array[TChain] of Integer = (
    1,   // Mainnet
    3,   // Ropsten
    4,   // Rinkeby
    5,   // Goerli
    42,  // Kovan
    1    // Ganache
  );

type
  EWeb3 = class(Exception);

type
  TWeb3 = record
    var
      Chain: TChain;
      URL  : string;
    class function New(const aURL: string): TWeb3; overload; static;
    class function New(aChain: TChain; const aURL: string): TWeb3; overload; static;
  end;

implementation

class function TWeb3.New(const aURL: string): TWeb3;
begin
  Result := New(Mainnet, aURL);
end;

class function TWeb3.New(aChain: TChain; const aURL: string): TWeb3;
begin
  Result.Chain := aChain;
  Result.URL   := aURL;
end;

end.
