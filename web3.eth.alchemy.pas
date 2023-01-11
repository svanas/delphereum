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

function endpoint(chain: TChain; const apiKey: string): IResult<string>; overload;
function endpoint(chain: TChain; protocol: TTransport; const apiKey: string): IResult<string>; overload;

implementation

uses
  // Delphi
  System.SysUtils;

function HTTPS(chain: TChain; const projectId: string): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok(Format('https://eth-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Goerli then
    Result := TResult<string>.Ok(Format('https://eth-goerli.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Optimism then
    Result := TResult<string>.Ok(Format('https://opt-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = OptimismGoerli then
    Result := TResult<string>.Ok(Format('https://opt-goerli.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Polygon then
    Result := TResult<string>.Ok(Format('https://polygon-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = PolygonMumbai then
    Result := TResult<string>.Ok(Format('https://polygon-mumbai.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Arbitrum then
    Result := TResult<string>.Ok(Format('https://arb-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = ArbitrumGoerli then
    Result := TResult<string>.Ok(Format('https://arb-goerli.g.alchemy.com/v2/%s', [projectId]))
  else if chain.Gateway[TTransport.HTTPS] <> '' then
    Result := TResult<string>.Ok(chain.Gateway[TTransport.HTTPS])
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

function WebSocket(chain: TChain; const projectId: string): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok(Format('wss://eth-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Goerli then
    Result := TResult<string>.Ok(Format('wss://eth-goerli.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Optimism then
    Result := TResult<string>.Ok(Format('wss://opt-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = OptimismGoerli then
    Result := TResult<string>.Ok(Format('wss://opt-goerli.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Polygon then
    Result := TResult<string>.Ok(Format('wss://polygon-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = PolygonMumbai then
    Result := TResult<string>.Ok(Format('wss://polygon-mumbai.g.alchemy.com/v2/%s', [projectId]))
  else if chain = Arbitrum then
    Result := TResult<string>.Ok(Format('wss://arb-mainnet.g.alchemy.com/v2/%s', [projectId]))
  else if chain = ArbitrumGoerli then
    Result := TResult<string>.Ok(Format('wss://arb-goerli.g.alchemy.com/v2/%s', [projectId]))
  else if chain.Gateway[TTransport.WebSocket] <> '' then
    Result := TResult<string>.Ok(chain.Gateway[TTransport.WebSocket])
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

function endpoint(chain: TChain; const apiKey: string): IResult<string>;
begin
  Result := endpoint(chain, TTransport.HTTPS, apiKey);
end;

function endpoint(chain: TChain; protocol: TTransport; const apiKey: string): IResult<string>;
begin
  if protocol = TTransport.WebSocket then
    Result := WebSocket(chain, apiKey)
  else
    Result := HTTPS(chain, apiKey);
end;

end.
