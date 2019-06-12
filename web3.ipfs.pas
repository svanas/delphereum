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
  web3.json,
  web3.types;

type
  TIpfsFile = record
    Name: string;
    Hash: string;
    Size: UInt64;
    function Endpoint: string;
  end;
  PIpfsFile = ^TIpfsFile;

type
  TASyncIpfsFile = reference to procedure(&file: PIpfsFile; err: Exception);

function add(const fileName: string; callback: TASyncJsonObject): IASyncResult; overload;
function add(const fileName: string; callback: TASyncIpfsFile): IASyncResult; overload;

function add(const apiBase, fileName: string; callback: TASyncJsonObject): IASyncResult; overload;
function add(const apiBase, fileName: string; callback: TASyncIpfsFile): IASyncResult; overload;

function pin(const hash: string; callback: TASyncJsonObject): IASyncResult; overload;
function pin(const apiBase, hash: string; callback: TASyncJsonObject): IASyncResult; overload;

function cat(const hash: string; callback: TASyncResponse): IASyncResult; overload;
function cat(const apiBase, hash: string; callback: TASyncResponse): IASyncResult; overload;

implementation

const
  IPFS_INFURA_BASE = 'https://ipfs.infura.io:5001';

{ TIpfsFile }

function TIpfsFile.Endpoint: string;
begin
  Result := 'https://gateway.ipfs.io/ipfs/' + TNetEncoding.URL.Encode(Hash);
end;

{ global functions }

function add(const fileName: string; callback: TASyncJsonObject): IASyncResult;
begin
  Result := add(IPFS_INFURA_BASE, fileName, callback);
end;

function add(const fileName: string; callback: TASyncIpfsFile): IASyncResult;
begin
  Result := add(IPFS_INFURA_BASE, fileName, callback);
end;

function add(const apiBase, fileName: string; callback: TASyncJsonObject): IASyncResult;
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
    Result := client.BeginPost(procedure(const aSyncResult: IASyncResult)
    begin
      try
        resp := THttpClient.EndASyncHttp(aSyncResult);
        if resp.StatusCode <> 200 then
          callback(nil, ENetHttpResponseException.Create(resp.ContentAsString(TEncoding.UTF8)))
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
    end, apiBase + '/api/v0/add', source, nil, [TNetHeader.Create('Content-Type', source.MimeTypeHeader)]);
  except
    on E: Exception do
      callback(nil, E);
  end;
end;

function add(const apiBase, fileName: string; callback: TASyncIpfsFile): IASyncResult;
var
  &file: TIpfsFile;
begin
  Result := add(apiBase, fileName, procedure(obj: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    &file.Name := GetPropAsStr(obj, 'Name');
    &file.Hash := GetPropAsStr(obj, 'Hash');
    &file.Size := GetPropAsInt(obj, 'Size');
    callback(@&file, nil);
  end);
end;

function pin(const hash: string; callback: TASyncJsonObject): IASyncResult;
begin
  Result := pin(IPFS_INFURA_BASE, hash, callback);
end;

function pin(const apiBase, hash: string; callback: TASyncJsonObject): IASyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
  obj   : TJsonObject;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IASyncResult)
    begin
      try
        resp := THttpClient.EndASyncHttp(aSyncResult);
        if resp.StatusCode <> 200 then
          callback(nil, ENetHttpResponseException.Create(resp.ContentAsString(TEncoding.UTF8)))
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
    end, apiBase + '/api/v0/pin/add?arg=' + TNetEncoding.URL.Encode(hash));
  except
    on E: Exception do
      callback(nil, E);
  end;
end;

function cat(const hash: string; callback: TASyncResponse): IASyncResult;
begin
  Result := cat(IPFS_INFURA_BASE, hash, callback);
end;

function cat(const apiBase, hash: string; callback: TASyncResponse): IASyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IASyncResult)
    begin
      try
        resp := THttpClient.EndASyncHttp(aSyncResult);
        if resp.StatusCode <> 200 then
          callback(nil, ENetHttpResponseException.Create(resp.ContentAsString(TEncoding.UTF8)))
        else
          callback(resp, nil);
      finally
        client.Free;
      end;
    end, apiBase + '/api/v0/cat?arg=' + TNetEncoding.URL.Encode(hash));
  except
    on E: Exception do
      callback(nil, E);
  end;
end;

end.
