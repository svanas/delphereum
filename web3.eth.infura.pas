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

function endpoint(const chain: TChain; const projectId: string): IResult<string>; overload;
function endpoint(const chain: TChain; const protocol: TTransport; const projectId: string): IResult<string>; overload;

implementation

uses
  // Delphi
  System.SysUtils;

function HTTPS(const chain: TChain; const projectId: string): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok(Format('https://mainnet.infura.io/v3/%s', [projectId]))
  else if chain = Goerli then
    Result := TResult<string>.Ok(Format('https://goerli.infura.io/v3/%s', [projectId]))
  else if chain = Sepolia then
    Result := TResult<string>.Ok(Format('https://sepolia.infura.io/v3/%s', [projectId]))
  else if chain = Optimism then
    Result := TResult<string>.Ok(Format('https://optimism-mainnet.infura.io/v3/%s', [projectId]))
  else if chain = OptimismSepolia then
    Result := TResult<string>.Ok(Format('https://optimism-sepolia.infura.io/v3/%s', [projectId]))
  else if chain = Polygon then
    Result := TResult<string>.Ok(Format('https://polygon-mainnet.infura.io/v3/%s', [projectId]))
  else if chain = PolygonMumbai then
    Result := TResult<string>.Ok(Format('https://polygon-mumbai.infura.io/v3/%s', [projectId]))
  else if chain = Arbitrum then
    Result := TResult<string>.Ok(Format('https://arbitrum-mainnet.infura.io/v3/%s', [projectId]))
  else if chain = ArbitrumSepolia then
    Result := TResult<string>.Ok(Format('https://arbitrum-sepolia.infura.io/v3/%s', [projectId]))
  else if chain.RPC[TTransport.HTTPS] <> '' then
    Result := TResult<string>.Ok(chain.RPC[TTransport.HTTPS])
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

function WebSocket(const chain: TChain; const projectId: string): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok(Format('wss://mainnet.infura.io/ws/v3/%s', [projectId]))
  else if chain = Goerli then
    Result := TResult<string>.Ok(Format('wss://goerli.infura.io/ws/v3/%s', [projectId]))
  else if chain = Sepolia then
    Result := TResult<string>.Ok(Format('wss://sepolia.infura.io/ws/v3/%s', [projectId]))
  else if chain = Polygon then
    Result := TResult<string>.Ok(Format('wss://polygon-mainnet.infura.io/ws/v3/%s', [projectId]))
  else if chain = PolygonMumbai then
    Result := TResult<string>.Ok(Format('wss://polygon-mumbai.infura.io/ws/v3/%s', [projectId]))
  else if chain.RPC[TTransport.WebSocket] <> '' then
    Result := TResult<string>.Ok(chain.RPC[TTransport.WebSocket])
  else
    Result := TResult<string>.Err('', TError.Create('%s not supported', [chain.Name]));
end;

function endpoint(const chain: TChain; const projectId: string): IResult<string>;
begin
  Result := endpoint(chain, TTransport.HTTPS, projectId);
end;

function endpoint(const chain: TChain; const protocol: TTransport; const projectId: string): IResult<string>;
begin
  if protocol = TTransport.WebSocket then
    Result := WebSocket(chain, projectId)
  else
    Result := HTTPS(chain, projectId);
end;

end.
