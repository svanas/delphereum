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

function endpoint(chain: TChain; const projectId: string): IResult<string>; overload;
function endpoint(chain: TChain; protocol: TProtocol; const projectId: string): IResult<string>; overload;

implementation

uses
  // Delphi
  System.SysUtils,
  System.TypInfo;

function endpoint(chain: TChain; const projectId: string): IResult<string>;
begin
  Result := endpoint(chain, HTTPS, projectId);
end;

function endpoint(chain: TChain; protocol: TProtocol; const projectId: string): IResult<string>;
const
  ENDPOINT: array[TChain] of array[TProtocol] of string = (
    { Ethereum        } ('https://eth-mainnet.g.alchemy.com/v2/%s', 'wss://eth-mainnet.g.alchemy.com/v2/%s'),
    { Ropsten         } ('https://eth-ropsten.g.alchemy.com/v2/%s', 'wss://eth-ropsten.g.alchemy.com/v2/%s'),
    { Rinkeby         } ('https://eth-rinkeby.g.alchemy.com/v2/%s', 'wss://eth-rinkeby.g.alchemy.com/v2/%s'),
    { Kovan           } ('https://eth-kovan.g.alchemy.com/v2/%s', 'wss://eth-kovan.g.alchemy.com/v2/%s'),
    { Goerli          } ('https://eth-goerli.g.alchemy.com/v2/%s', 'wss://eth-goerli.g.alchemy.com/v2/%s'),
    { Optimism        } ('https://opt-mainnet.g.alchemy.com/v2/%s', 'wss://opt-mainnet.g.alchemy.com/v2/%s'),
    { OptimismGoerli  } ('https://opt-goerli.g.alchemy.com/v2/%s', 'wss://opt-goerli.g.alchemy.com/v2/%s'),
    { RSK             } ('https://public-node.rsk.co', ''),
    { RSK_test_net    } ('https://public-node.testnet.rsk.co', ''),
    { BNB             } ('https://bsc-dataseed.binance.org', ''),
    { BNB_test_net    } ('https://data-seed-prebsc-1-s1.binance.org:8545', ''),
    { Gnosis          } ('https://rpc.gnosischain.com', 'wss://rpc.gnosischain.com/wss'),
    { Polygon         } ('https://polygon-mainnet.g.alchemy.com/v2/%s', 'wss://polygon-mainnet.g.alchemy.com/v2/%s'),
    { PolygonMumbai   } ('https://polygon-mumbai.g.alchemy.com/v2/%s', 'wss://polygon-mumbai.g.alchemy.com/v2/%s'),
    { Fantom          } ('https://rpc.fantom.network', ''),
    { Fantom_test_net } ('https://rpc.testnet.fantom.network', ''),
    { Arbitrum        } ('https://arb-mainnet.g.alchemy.com/v2/%s', 'wss://arb-mainnet.g.alchemy.com/v2/%s'),
    { ArbitrumRinkeby } ('https://arb-rinkeby.g.alchemy.com/v2/%s', 'wss://arb-rinkeby.g.alchemy.com/v2/%s'),
    { Sepolia         } ('https://rpc.sepolia.org', '')
  );
begin
  const URL = ENDPOINT[chain][protocol];
  if URL <> '' then
    Result := TResult<string>.Ok(Format(URL, [projectId]))
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

end.
