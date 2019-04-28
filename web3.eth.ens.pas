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
  web3.eth.types,
  web3.types;

type
  ENS = class(EWeb3);

function  namehash(const name: string): string;
procedure resolver(client: TWeb3; const name: string; callback: TASyncAddress);
procedure addr    (client: TWeb3; const name: string; callback: TASyncAddress);
procedure reverse (client: TWeb3; addr: TAddress; callback: TASyncString);

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
  deployments: array[TChain] of TAddress = (
    '0x314159265dD8dbb310642f98f50C066173C1259b', // Mainnet
    '0x112234455C3a32FD11230C42E7Bccd4A84e02010', // Ropsten
    '0xe7410170f87102DF0055eB195163A03B7F2Bff4A', // Rinkeby
    '0x112234455C3a32FD11230C42E7Bccd4A84e02010', // Goerli
    '',                                           // Kovan
    ''                                            // Ganache
  );

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

procedure resolver(client: TWeb3; const name: string; callback: TASyncAddress);
var
  registry: TAddress;
begin
  registry := deployments[client.Chain];
  if (registry = '')
  or (registry = ADDRESS_ZERO) then
    raise ENS.CreateFmt('ENS is not supported on %s.', [GetEnumName(TypeInfo(TChain), Ord(client.Chain))]);
  web3.eth.call(client, registry, 'resolver(bytes32)', [namehash(name)], procedure(const hex: string; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TAddress.New(hex), nil)
  end);
end;

procedure addr(client: TWeb3; const name: string; callback: TASyncAddress);
begin
  resolver(client, name, procedure(resolver: TAddress; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.call(client, resolver, 'addr(bytes32)', [namehash(name)], procedure(const hex: string; err: Exception)
      begin
        if Assigned(err) then
          callback('', err)
        else
          callback(TAddress.New(hex), nil)
      end);
  end);
end;

procedure reverse(client: TWeb3; addr: TAddress; callback: TASyncString);
var
  name: string;
begin
  name := string(addr).ToLower + '.addr.reverse';
  while Copy(name, Low(name), 2) = '0x' do
    Delete(name, Low(name), 2);
  resolver(client, name, procedure(resolver: TAddress; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.call(client, resolver, 'name(bytes32)', [namehash(name)], procedure(tup: TTuple; err: Exception)
      begin
        if Assigned(err) then
          callback('', err)
        else
          callback(tup.ToString, nil);
      end);
  end);
end;

end.
