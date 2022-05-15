{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.contract;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  TCustomContract = class abstract(TInterfacedObject)
  strict private
    FClient  : IWeb3;
    FContract: TAddress;
  public
    constructor Create(aClient: IWeb3; aContract: TAddress); virtual;
    function Client  : IWeb3;
    function Contract: TAddress;
  end;

implementation

{ TCustomContract }

constructor TCustomContract.Create(aClient: IWeb3; aContract: TAddress);
begin
  inherited Create;
  FClient   := aClient;
  FContract := aContract;
end;

function TCustomContract.Client: IWeb3;
begin
  Result := FClient;
end;

function TCustomContract.Contract: TAddress;
begin
  Result := FContract;
end;

end.
