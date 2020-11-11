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

unit web3.eth.alchemy;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  EAlchemy = class(EWeb3);

function endpoint(chain: TChain; const projectId: string): string;

implementation

uses
  // Delphi
  System.SysUtils,
  System.TypInfo;

function endpoint(chain: TChain; const projectId: string): string;
const
  ENDPOINT: array[TChain] of string = (
    'https://eth-mainnet.alchemyapi.io/v2/%s', // Mainnet
    'https://eth-ropsten.alchemyapi.io/v2/%s', // Ropsten
    'https://eth-rinkeby.alchemyapi.io/v2/%s', // Rinkeby
    'https://eth-goerli.alchemyapi.io/v2/%s',  // Goerli
    '',                                        // RSK_main_net
    '',                                        // RSK_test_net
    'https://eth-kovan.alchemyapi.io/v2/%s',   // Kovan
    '',                                        // xDAI
    ''                                         // Ganache
  );
begin
  Result := ENDPOINT[chain];
  if Result = '' then
    raise EAlchemy.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))])
  else
    Result := Format(Result, [projectId]);
end;

end.
