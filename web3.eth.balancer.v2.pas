{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2022 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.balancer.v2;

{$I web3.inc}

interface

uses
  web3,
  web3.eth.contract,
  web3.eth.types;

type
  TVault = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
  end;

procedure getPoolId(chain: TChain; asset0, asset1: TAddress; callback: TAsyncString);

implementation

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // web3
  web3.graph,
  web3.json;

{ TVault }

constructor TVault.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0xBA12222222228d8Ba445958a75a0704d566BF2C8');
end;

type
  IPoolDoesNotExist = interface(IError)
  ['{98E7E985-B74E-4D20-84A4-E8A2F8060D56}']
  end;

type
  TPoolDoesNotExist = class(TError, IPoolDoesNotExist)
  public
    constructor Create;
  end;

constructor TPoolDoesNotExist.Create;
begin
  inherited Create('Pool does not exist');
end;

procedure getPoolId(chain: TChain; asset0, asset1: TAddress; callback: TAsyncString);
const
  QUERY = '{"query":"{pools(where: {tokensList: [\"%s\", \"%s\"]}, orderBy: totalLiquidity, orderDirection: desc) { id }}"}';
const
  SUBGRAPH: array[TChain] of string = (
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-v2',          // Ethereum,
    '',                                                                           // Ropsten
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-rinkeby-v2',  // Rinkeby
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-kovan-v2',    // Kovan
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-goerli-v2',   // Goerli
    '',                                                                           // Optimism
    '',                                                                           // Optimism_test_net
    '',                                                                           // RSK
    '',                                                                           // RSK_test_net
    '',                                                                           // BSC
    '',                                                                           // BSC_test_net
    '',                                                                           // Gnosis
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-polygon-v2',  // Polygon
    '',                                                                           // Polygon_test_net
    '',                                                                           // Fantom
    '',                                                                           // Fantom_test_net
    'https://api.thegraph.com/subgraphs/name/balancer-labs/balancer-arbitrum-v2', // Arbitrum
    ''                                                                            // Arbitrum_test_net
  );
begin
  var execute := procedure(token0, token1: TAddress; callback: TAsyncString)
  begin
    web3.graph.execute(SUBGRAPH[chain], Format(QUERY, [string(token0), string(token1)]), procedure(resp: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        callback('', err);
        EXIT;
      end;
      var data := web3.json.getPropAsObj(resp, 'data');
      if Assigned(data) then
      begin
        var pools := web3.json.getPropAsArr(data, 'pools');
        if Assigned(pools) and (pools.Count > 0) then
        begin
          callback(web3.json.getPropAsStr(pools[0], 'id'), nil);
          EXIT;
        end;
      end;
      callback('', TPoolDoesNotExist.Create);
    end);
  end;

  execute(asset0, asset1, procedure(const id: string; err: IError)
  begin
    if Assigned(err) and Supports(err, IPoolDoesNotExist) then
      execute(asset1, asset0, callback)
    else
      callback(id, err);
  end);
end;

end.
