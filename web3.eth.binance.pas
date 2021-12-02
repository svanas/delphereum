{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.binance;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  EBinance = class(EWeb3);

function endpoint(chain: TChain): string;

implementation

uses
  // Delphi
  System.TypInfo;

function endpoint(chain: TChain): string;
begin
  if chain = BSC then
    Result := 'https://bsc-dataseed.binance.org/'
  else if chain = BSC_test_net then
    Result := 'https://data-seed-prebsc-1-s1.binance.org:8545/'
  else
    raise EBinance.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))]);
end;

end.
