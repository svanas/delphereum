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

function endpoint(chain: TChain; const projectId: string): string; overload;
function endpoint(chain: TChain; protocol: TProtocol; const projectId: string): string; overload;

implementation

uses
  // Delphi
  System.SysUtils,
  System.TypInfo,
  // web3
  web3.eth.binance;

function endpoint(chain: TChain; const projectId: string): string;
begin
  Result := endpoint(chain, HTTPS, projectId);
end;

function endpoint(chain: TChain; protocol: TProtocol; const projectId: string): string;
const
  ENDPOINT: array[TChain] of array[TProtocol] of string = (
    ('https://eth-mainnet.alchemyapi.io/v2/%s', 'wss://eth-mainnet.ws.alchemyapi.io/v2/%s'), // Mainnet
    ('https://eth-ropsten.alchemyapi.io/v2/%s', 'wss://eth-ropsten.ws.alchemyapi.io/v2/%s'), // Ropsten
    ('https://eth-rinkeby.alchemyapi.io/v2/%s', 'wss://eth-rinkeby.ws.alchemyapi.io/v2/%s'), // Rinkeby
    ('https://eth-kovan.alchemyapi.io/v2/%s',   'wss://eth-kovan.ws.alchemyapi.io/v2/%s'),   // Kovan
    ('https://eth-goerli.alchemyapi.io/v2/%s',  'wss://eth-goerli.ws.alchemyapi.io/v2/%s'),  // Goerli
    ('', ''),                                                                                // Optimism
    ('', ''),                                                                                // Optimism_test_net
    ('', ''),                                                                                // RSK_main_net
    ('', ''),                                                                                // RSK_test_net
    ('', ''),                                                                                // BSC_main_net
    ('', ''),                                                                                // BSC_test_net
    ('', ''),                                                                                // xDai
    ('https://arb-mainnet.g.alchemy.com/v2/%s', '')                                          // Arbitrum
  );
begin
  Result := ENDPOINT[chain][protocol];
  if Result <> '' then
  begin
    Result := Format(Result, [projectId]);
    EXIT;
  end;
  if chain in [BSC_main_net, BSC_test_net] then
  begin
    Result := web3.eth.binance.endpoint(chain);
    EXIT;
  end;
  raise EAlchemy.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))]);
end;

end.
