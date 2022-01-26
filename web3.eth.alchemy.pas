{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
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
    { Ethereum          } ('https://eth-mainnet.alchemyapi.io/v2/%s', 'wss://eth-mainnet.ws.alchemyapi.io/v2/%s'),
    { Ropsten           } ('https://eth-ropsten.alchemyapi.io/v2/%s', 'wss://eth-ropsten.ws.alchemyapi.io/v2/%s'),
    { Rinkeby           } ('https://eth-rinkeby.alchemyapi.io/v2/%s', 'wss://eth-rinkeby.ws.alchemyapi.io/v2/%s'),
    { Kovan             } ('https://eth-kovan.alchemyapi.io/v2/%s', 'wss://eth-kovan.ws.alchemyapi.io/v2/%s'),
    { Goerli            } ('https://eth-goerli.alchemyapi.io/v2/%s', 'wss://eth-goerli.ws.alchemyapi.io/v2/%s'),
    { Optimism          } ('https://opt-mainnet.g.alchemy.com/v2/%s', 'wss://opt-mainnet.g.alchemy.com/v2/%s'),
    { Optimism_test_net } ('https://opt-kovan.g.alchemy.com/v2/y%s', 'wss://opt-kovan.g.alchemy.com/v2/%s'),
    { RSK               } ('', ''),
    { RSK_test_net      } ('', ''),
    { BSC               } ('', ''),
    { BSC_test_net      } ('', ''),
    { Gnosis            } ('https://rpc.gnosischain.com', 'wss://rpc.gnosischain.com/wss'),
    { Polygon           } ('https://polygon-mainnet.g.alchemy.com/v2/%s', 'wss://polygon-mainnet.g.alchemy.com/v2/%s'),
    { Polygon_test_net  } ('https://polygon-mumbai.g.alchemy.com/v2/%s', 'wss://polygon-mumbai.g.alchemy.com/v2/%s'),
    { Fantom            } ('https://rpc.ftm.tools', ''),
    { Fantom_test_net   } ('https://rpc.testnet.fantom.network', ''),
    { Arbitrum          } ('https://arb-mainnet.g.alchemy.com/v2/%s', 'wss://arb-mainnet.g.alchemy.com/v2/%s'),
    { Arbitrum_test_net } ('https://arb-rinkeby.g.alchemy.com/v2/%s', 'wss://arb-rinkeby.g.alchemy.com/v2/%s')
  );
begin
  Result := ENDPOINT[chain][protocol];
  if Result <> '' then
  begin
    Result := Format(Result, [projectId]);
    EXIT;
  end;
  if chain in [BSC, BSC_test_net] then
  begin
    Result := web3.eth.binance.endpoint(chain);
    EXIT;
  end;
  raise EAlchemy.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))]);
end;

end.
