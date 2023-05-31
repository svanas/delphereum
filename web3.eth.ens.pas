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

unit web3.eth.ens;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth.types;

function namehash(const name: string): string;
// resolve a name to an Ethereum address
procedure addr(const client: IWeb3; const name: string; const callback: TProc<TAddress, IError>);
// retrieves text metadata for a name
procedure text(const client: IWeb3; const name, key: string; const callback: TProc<TTuple, IError>);
// reverse resolution maps from an address back to a name
procedure reverse(const client: IWeb3; const addr: TAddress; const callback: TProc<string, IError>);

implementation

uses
  // Delphi
  System.Classes,
  System.TypInfo,
  // web3
  web3.eth,
  web3.utils;

const
  ENS_REGISTRY: TAddress = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';

function namehash(const name: string): string;
begin
  const node = (function: TBytes
  begin
    SetLength(Result, 32);
    if name <> '' then
    begin
      const labels = TStringList.Create;
      try
        labels.Delimiter     := '.';
        labels.DelimitedText := name;
        for var idx := labels.Count - 1 downto 0 do
        begin
          const &label = TEncoding.UTF8.GetBytes(labels[idx]);
          Result := web3.utils.sha3(Result + web3.utils.sha3(&label));
        end;
      finally
        labels.Free;
      end;
    end;
  end)();
  Result := web3.utils.toHex(node);
end;

procedure resolver(const client: IWeb3; const name: string; const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(client, ENS_REGISTRY, 'resolver(bytes32)', [namehash(name)], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// resolve a name to an Ethereum address
procedure addr(const client: IWeb3; const name: string; const callback: TProc<TAddress, IError>);
begin
  resolver(client, name, procedure(resolver: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      web3.eth.call(client, resolver, 'addr(bytes32)', [namehash(name)], procedure(hex: string; err: IError)
      begin
        if Assigned(err) then
          callback(TAddress.Zero, err)
        else
          callback(TAddress.Create(hex), nil);
      end);
  end);
end;

// retrieves text metadata for a name.
// each name may have multiple pieces of metadata, identified by a unique string key.
// if no text data exists for node with the key key, the empty string is returned.
procedure text(const client: IWeb3; const name, key: string; const callback: TProc<TTuple, IError>);
begin
  resolver(client, name, procedure(resolver: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.call(client, resolver, 'text(bytes32,string)', [namehash(name), key], callback);
  end);
end;

// reverse resolution maps from an address back to a name
procedure reverse(const client: IWeb3; const addr: TAddress; const callback: TProc<string, IError>);
begin
  var name := string(addr).ToLower + '.addr.reverse';
  while Copy(name, System.Low(name), 2).ToLower = '0x' do
    Delete(name, System.Low(name), 2);
  resolver(client, name, procedure(resolver: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      if resolver.IsZero then
        callback(string(addr), nil)
      else
        web3.eth.call(client, resolver, 'name(bytes32)', [namehash(name)], procedure(tup: TTuple; err: IError)
        begin
          if Assigned(err) then
            callback('', err)
          else
            callback(tup.ToString, nil);
        end);
  end);
end;

end.
