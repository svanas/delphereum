{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.ens;

{$I web3.inc}

interface

uses
  // web3
  web3,
  web3.eth.types;

function  namehash(const name: string): string;
procedure resolver(client: TWeb3; const name: string; callback: TAsyncAddress);
procedure addr    (client: TWeb3; const name: string; callback: TAsyncAddress);
procedure reverse (client: TWeb3; addr: TAddress; callback: TAsyncString);

implementation

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.TypInfo,
  // web3
  web3.eth,
  web3.utils;

const
  ENS_REGISTRY: TAddress = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';

function namehash(const name: string): string;
var
  labels: TStrings;
  idx   : Integer;
  &label: TBytes;
  node  : TBytes;
begin
  SetLength(node, 32);
  if name <> '' then
  begin
    labels := TStringList.Create;
    try
      labels.Delimiter     := '.';
      labels.DelimitedText := name;
      for idx := labels.Count - 1 downto 0 do
      begin
        &label := TEncoding.UTF8.GetBytes(labels[idx]);
        node := web3.utils.sha3(node + web3.utils.sha3(&label));
      end;
    finally
      labels.Free;
    end;
  end;
  Result := web3.utils.toHex(node);
end;

procedure resolver(client: TWeb3; const name: string; callback: TAsyncAddress);
begin
  web3.eth.call(client, ENS_REGISTRY, 'resolver(bytes32)', [namehash(name)], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TAddress.New(hex), nil)
  end);
end;

procedure addr(client: TWeb3; const name: string; callback: TAsyncAddress);
begin
  resolver(client, name, procedure(resolver: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.call(client, resolver, 'addr(bytes32)', [namehash(name)], procedure(const hex: string; err: IError)
      begin
        if Assigned(err) then
          callback('', err)
        else
          callback(TAddress.New(hex), nil)
      end);
  end);
end;

procedure reverse(client: TWeb3; addr: TAddress; callback: TAsyncString);
var
  name: string;
begin
  name := string(addr).ToLower + '.addr.reverse';
  while Copy(name, Low(name), 2) = '0x' do
    Delete(name, Low(name), 2);
  resolver(client, name, procedure(resolver: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
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
