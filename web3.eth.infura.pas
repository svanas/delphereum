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

unit web3.eth.infura;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  EInfura = class(EWeb3);

function endpoint(chain: TChain; const projectId: string): string;

implementation

uses
  // Delphi
  System.SysUtils,
  System.TypInfo;

function endpoint(chain: TChain; const projectId: string): string;
const
  ENDPOINT: array[TChain] of string = (
    'https://mainnet.infura.io/v3/%s', // Mainnet
    'https://ropsten.infura.io/v3/%s', // Ropsten
    'https://rinkeby.infura.io/v3/%s', // Rinkeby
    'https://goerli.infura.io/v3/%s',  // Goerli
    '',                                // RSK_main_net
    '',                                // RSK_test_net
    'https://kovan.infura.io/v3/%s',   // Kovan
    '',                                // xDAI
    ''                                 // Ganache
  );
begin
  Result := ENDPOINT[chain];
  if Result = '' then
    raise EInfura.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))])
  else
    Result := Format(Result, [projectId]);
end;

end.
