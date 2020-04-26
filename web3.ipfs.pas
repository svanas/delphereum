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

unit web3.ipfs;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.Net.HttpClient,
  System.Net.Mime,
  System.NetEncoding,
  System.Net.URLClient,
  System.SysUtils,
  System.Types,
  // Web3
  web3,
  web3.eth.types,
  web3.json;

type
  TGateway = (
    ProtocolLabs,
    Infura,
    Cloudflare);

type
  TFile = record
    Name: string;
    Hash: string;
    Size: UInt64;
    function Endpoint(Gateway: TGateway): string;
  end;
  PFile = ^TFile;

type
  TAsyncFile = reference to procedure(&file: PFile; err: IError);

function add(const fileName: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function add(const fileName: string; callback: TAsyncFile): IAsyncResult; overload;

function add(const apiHost, fileName: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function add(const apiHost, fileName: string; callback: TAsyncFile): IAsyncResult; overload;

function pin(const hash: string; callback: TAsyncJsonObject): IAsyncResult; overload;
function pin(const apiHost, hash: string; callback: TAsyncJsonObject): IAsyncResult; overload;

function cat(const hash: string; callback: TAsyncResponse): IAsyncResult; overload;
function cat(const apiHost, hash: string; callback: TAsyncResponse): IAsyncResult; overload;

implementation

const
  IPFS_HOST: array[TGateway] of string = (
    'https://gateway.ipfs.io',
    'https://ipfs.infura.io',
    'https://cloudflare-ipfs.com');

{ TFile }

function TFile.Endpoint(Gateway: TGateway): string;
begin
  Result := IPFS_HOST[Gateway] + '/ipfs/' + TNetEncoding.URL.Encode(Hash);
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
var
  client: THttpClient;
  source: TMultipartFormData;
  resp  : IHttpResponse;
  obj   : TJsonObject;
begin
  try
    client := THttpClient.Create;
    source := TMultipartFormData.Create;
    source.AddFile('file', fileName);
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if resp.StatusCode <> 200 then
          callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)))
        else
        begin
          obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
          if Assigned(obj) then
          try
            callback(obj, nil);
          finally
            obj.Free;
          end;
        end;
      finally
        source.Free;
        client.Free;
      end;
    end, apiHost + '/api/v0/add', source, nil, [TNetHeader.Create('Content-Type', source.MimeTypeHeader)]);
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

function add(const apiHost, fileName: string; callback: TAsyncFile): IAsyncResult;
var
  &file: TFile;
begin
  Result := add(apiHost, fileName, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    &file.Name := getPropAsStr(obj, 'Name');
    &file.Hash := getPropAsStr(obj, 'Hash');
    &file.Size := getPropAsInt(obj, 'Size');
    callback(@&file, nil);
  end);
end;

function pin(const hash: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := pin('https://ipfs.infura.io:5001', hash, callback);
end;

function pin(const apiHost, hash: string; callback: TAsyncJsonObject): IAsyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
  obj   : TJsonObject;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if resp.StatusCode <> 200 then
          callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)))
        else
        begin
          obj := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
          if Assigned(obj) then
          try
            callback(obj, nil);
          finally
            obj.Free;
          end;
        end;
      finally
        client.Free;
      end;
    end, apiHost + '/api/v0/pin/add?arg=' + TNetEncoding.URL.Encode(hash));
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

function cat(const hash: string; callback: TAsyncResponse): IAsyncResult;
begin
  Result := cat('https://ipfs.infura.io:5001', hash, callback);
end;

function cat(const apiHost, hash: string; callback: TAsyncResponse): IAsyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if resp.StatusCode <> 200 then
          callback(nil, TError.Create(resp.ContentAsString(TEncoding.UTF8)))
        else
          callback(resp, nil);
      finally
        client.Free;
      end;
    end, apiHost + '/api/v0/cat?arg=' + TNetEncoding.URL.Encode(hash));
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

end.
