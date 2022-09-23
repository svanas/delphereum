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
  System.TypInfo;

function endpoint(chain: TChain; const projectId: string): string;
begin
  Result := endpoint(chain, HTTPS, projectId);
end;

function endpoint(chain: TChain; protocol: TProtocol; const projectId: string): string;
const
  ENDPOINT: array[TChain] of array[TProtocol] of string = (
    { Ethereum        } ('https://mainnet.infura.io/v3/%s', 'wss://mainnet.infura.io/ws/v3/%s'),
    { Ropsten         } ('https://ropsten.infura.io/v3/%s', 'wss://ropsten.infura.io/ws/v3/%s'),
    { Rinkeby         } ('https://rinkeby.infura.io/v3/%s', 'wss://rinkeby.infura.io/ws/v3/%s'),
    { Kovan           } ('https://kovan.infura.io/v3/%s', 'wss://kovan.infura.io/ws/v3/%s'),
    { Goerli          } ('https://goerli.infura.io/v3/%s', 'wss://goerli.infura.io/ws/v3/%s'),
    { Optimism        } ('https://optimism-mainnet.infura.io/v3/%s', ''),
    { OptimismGoerli  } ('https://optimism-goerli.infura.io/v3/%s', ''),
    { RSK             } ('https://public-node.rsk.co', ''),
    { RSK_test_net    } ('https://public-node.testnet.rsk.co', ''),
    { BNB             } ('https://bsc-dataseed.binance.org', ''),
    { BNB_test_net    } ('https://data-seed-prebsc-1-s1.binance.org:8545', ''),
    { Gnosis          } ('https://rpc.gnosischain.com', 'wss://rpc.gnosischain.com/wss'),
    { Polygon         } ('https://polygon-mainnet.infura.io/v3/%s', ''),
    { PolygonMumbai   } ('https://polygon-mumbai.infura.io/v3/%s', ''),
    { Fantom          } ('https://rpc.ftm.tools', ''),
    { Fantom_test_net } ('https://rpc.testnet.fantom.network', ''),
    { Arbitrum        } ('https://arbitrum-mainnet.infura.io/v3/%s', ''),
    { ArbitrumRinkeby } ('https://arbitrum-rinkeby.infura.io/v3/%s', ''),
    { Sepolia         } ('https://nunki.htznr.fault.dev/rpc', 'wss://nunki.htznr.fault.dev/ws')
  );
begin
  Result := ENDPOINT[chain][protocol];
  if Result <> '' then
  begin
    Result := Format(Result, [projectId]);
    EXIT;
  end;
  raise EInfura.CreateFmt('%s not supported', [chain.Name]);
end;

end.
