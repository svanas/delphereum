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

function namehash(const name: string): string;
// resolve a name to an Ethereum address
procedure addr(client: IWeb3; const name: string; callback: TAsyncAddress);
// retrieves text metadata for a name
procedure text(client: IWeb3; const name, key: string; callback: TAsyncTuple);
// reverse resolution maps from an address back to a name
procedure reverse(client: IWeb3; addr: TAddress; callback: TAsyncString);

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

procedure resolver(client: IWeb3; const name: string; callback: TAsyncAddress);
begin
  web3.eth.call(client, ENS_REGISTRY, 'resolver(bytes32)', [namehash(name)], procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.New(hex), nil);
  end);
end;

// resolve a name to an Ethereum address
procedure addr(client: IWeb3; const name: string; callback: TAsyncAddress);
begin
  resolver(client, name, procedure(resolver: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      web3.eth.call(client, resolver, 'addr(bytes32)', [namehash(name)], procedure(const hex: string; err: IError)
      begin
        if Assigned(err) then
          callback(EMPTY_ADDRESS, err)
        else
          callback(TAddress.New(hex), nil);
      end);
  end);
end;

// retrieves text metadata for a name.
// each name may have multiple pieces of metadata, identified by a unique string key.
// if no text data exists for node with the key key, the empty string is returned.
procedure text(client: IWeb3; const name, key: string; callback: TAsyncTuple);
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
procedure reverse(client: IWeb3; addr: TAddress; callback: TAsyncString);
var
  name: string;
begin
  name := string(addr).ToLower + '.addr.reverse';
  while Copy(name, System.Low(name), 2) = '0x' do
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
