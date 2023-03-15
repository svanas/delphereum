{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.nonce;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.sync;

procedure get(
  const client  : IWeb3;
  const address : TAddress;
  const callback: TProc<BigInteger, IError>);

implementation

var
  _nonce: ICriticalBigInt;

function nonce: ICriticalBigInt;
begin
  if not Assigned(_nonce) then
    _nonce := TCriticalBigInt.Create(-1);
  Result := _nonce;
end;

procedure get(
  const client  : IWeb3;
  const address : TAddress;
  const callback: TProc<BigInteger, IError>);
begin
  nonce.Enter;
  try
    if nonce.Get > -1 then
    begin
      callback(nonce.Inc, nil);
      EXIT;
    end;
  finally
    nonce.Leave;
  end;
  web3.eth.getTransactionCount(client, address, procedure(cnt: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    nonce.Enter;
    try
      nonce.Put(cnt);
      callback(nonce.Get, nil);
    finally
      nonce.Leave;
    end;
  end);
end;

end.
