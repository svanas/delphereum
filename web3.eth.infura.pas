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
    ('https://mainnet.infura.io/v3/%s', 'wss://mainnet.infura.io/ws/v3/%s'), // Mainnet
    ('https://ropsten.infura.io/v3/%s', 'wss://ropsten.infura.io/ws/v3/%s'), // Ropsten
    ('https://rinkeby.infura.io/v3/%s', 'wss://rinkeby.infura.io/ws/v3/%s'), // Rinkeby
    ('https://kovan.infura.io/v3/%s',   'wss://kovan.infura.io/ws/v3/%s'),   // Kovan
    ('https://goerli.infura.io/v3/%s',  'wss://goerli.infura.io/ws/v3/%s'),  // Goerli
    ('', ''),                                                                // Optimism
    ('', ''),                                                                // Optimism_test_net
    ('', ''),                                                                // RSK_main_net
    ('', ''),                                                                // RSK_test_net
    ('', ''),                                                                // BSC_main_net
    ('', ''),                                                                // BSC_test_net
    ('', '')                                                                 // xDai
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
  raise EInfura.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))]);
end;

end.
