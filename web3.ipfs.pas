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

unit web3.ipfs;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.http;

type
  TGateway = (
    Canonical,
    ProtocolLabs,
    Infura,
    Cloudflare);

type
  IFile = interface
    function Name: string;
    function Hash: string;
    function Size: UInt64;
    function Endpoint(Gateway: TGateway): string;
  end;

type
  TAsyncFile = reference to procedure(F: IFile; E: IError);

function add(const fileName: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function add(const fileName: string; callback: TAsyncFile): IAsyncResult; overload;

function add(const apiHost, fileName: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function add(const apiHost, fileName: string; callback: TAsyncFile): IAsyncResult; overload;

function pin(const hash: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function pin(const apiHost, hash: string; callback: TAsyncJsonObject): IAsyncResult; overload;

function cat(const hash: string; callback: TAsyncResponse): IAsyncResult; overload;
function cat(const apiHost, hash: string; callback: TAsyncResponse): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  System.NetEncoding,
  System.Net.Mime,
  System.Net.URLClient,
  // web3
  web3.json;

const
  IPFS_HOST: array[TGateway] of string = (
    'ipfs://',
    'https://gateway.ipfs.io/',
    'https://ipfs.infura.io/',
    'https://cloudflare-ipfs.com/');

{ TFile }

type
  TFile = class(TDeserialized<TJsonObject>, IFile)
  public
    function Name: string;
    function Hash: string;
    function Size: UInt64;
    function Endpoint(Gateway: TGateway): string;
  end;

function TFile.Name: string;
begin
  Result := getPropAsStr(FJsonValue, 'Name');
end;

function TFile.Hash: string;
begin
  Result := getPropAsStr(FJsonValue, 'Hash');
end;

function TFile.Size: UInt64;
begin
  Result := getPropAsInt(FJsonValue, 'Size');
end;

function TFile.Endpoint(Gateway: TGateway): string;
begin
  Result := IPFS_HOST[Gateway] + 'ipfs/' + TNetEncoding.URL.Encode(Hash);
end;

{ global functions }

function add(const fileName: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := add('https://ipfs.infura.io:5001', fileName, callback);
end;

function add(const fileName: string; callback: TAsyncFile): IAsyncResult;
begin
  Result := add('https://ipfs.infura.io:5001', fileName, callback);
end;

function add(const apiHost, fileName: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  const source = TMultipartFormData.Create;
  source.AddFile('file', fileName);
  web3.http.post(
    apiHost + '/api/v0/add',
    source,
    [TNetHeader.Create('Content-Type', source.MimeTypeHeader)],
    callback
  );
end;

function add(const apiHost, fileName: string; callback: TAsyncFile): IAsyncResult;
begin
  Result := add(apiHost, fileName, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    callback(TFile.Create(obj), nil);
  end);
end;

function pin(const hash: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := pin('https://ipfs.infura.io:5001', hash, callback);
end;

function pin(const apiHost, hash: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get(
    apiHost + '/api/v0/pin/add?arg=' + TNetEncoding.URL.Encode(hash),
    [], callback
  );
end;

function cat(const hash: string; callback: TAsyncResponse): IAsyncResult;
begin
  Result := cat('https://ipfs.infura.io:5001', hash, callback);
end;

function cat(const apiHost, hash: string; callback: TAsyncResponse): IAsyncResult;
begin
  Result := web3.http.get(
    apiHost + '/api/v0/cat?arg=' + TNetEncoding.URL.Encode(hash),
    [], callback
  );
end;

end.
