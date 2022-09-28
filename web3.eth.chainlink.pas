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

unit web3.eth.chainlink;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.types;

type
  TAggregatorV3 = class(TCustomContract)
  public
    procedure LatestRoundData(callback: TProc<TTuple, IError>);
    procedure Decimals(callback: TProc<BigInteger, IError>);
    procedure Price(callback: TProc<Double, IError>);
  end;

implementation

uses
  // Delphi
  System.Math;

procedure TAggregatorV3.LatestRoundData(callback: TProc<TTuple, IError>);
begin
  web3.eth.call(Client, Contract, 'latestRoundData()', [], callback);
end;

procedure TAggregatorV3.Decimals(callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'decimals()', [], callback);
end;

procedure TAggregatorV3.Price(callback: TProc<Double, IError>);
begin
  Self.LatestRoundData(procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    if tup.Empty then
    begin
      callback(0, TError.Create('latestRoundData() returned 0x'));
      EXIT;
    end;
    Self.Decimals(procedure(decimals: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(0, err);
        EXIT;
      end;
      callback(tup[1].toInt64 / Power(10, decimals.AsInteger), nil);
    end);
  end);
end;

end.
