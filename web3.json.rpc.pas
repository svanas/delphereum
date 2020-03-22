{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.json.rpc;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  System.Classes,
  System.SysUtils,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient,
  // Web3
  web3,
  web3.json;

type
  EJsonRpc = class(EWeb3)
  private
    FCode: Integer;
  public
    constructor Create(aCode: Integer; const aMsg: string);
    property Code: Integer read FCode;
  end;

type
  TAsyncResponse = reference to procedure(resp: TJsonObject; err: Exception);

function send(const URL, method: string; args: array of const; callback: TAsyncResponse): IAsyncResult; overload;
function send(const URL, method: string; args: array of const): TJsonObject; overload;

implementation

var
  id: Cardinal;

{ EJsonRpc }

constructor EJsonRpc.Create(aCode: Integer; const aMsg: string);
begin
  inherited Create(aMsg);
  FCode := aCode;
end;

{ global functions }

function formatArgs(args: array of const): string;
var
  arg: TVarRec;
begin
  Result := '[';
  try
    for arg in args do
    begin
      if Result.Length > 1 then
        Result := Result + ', ';
      case arg.VType of
        vtInteger:
          Result := Result + '0x' + IntToHex(arg.VInteger, 0);
        vtString:
          Result := Result + quoteString(UnicodeString(PShortString(arg.VAnsiString)^), '"');
        vtObject:
          Result := Result + web3.json.marshal(arg.VObject as TJsonObject);
        vtWideString:
          Result := Result + quoteString(WideString(arg.VWideString^), '"');
        vtInt64:
          Result := Result + '0x' + IntToHex(arg.VInt64^, 0);
        vtUnicodeString:
          Result := Result + quoteString(string(arg.VUnicodeString), '"');
      end;
    end;
  finally
    Result := Result + ']';
  end;
end;

function getPayload(const method: string; args: array of const): string;
begin
  Inc(id);
  Result := Format(
    '{"jsonrpc": "2.0", "method": %s, "params": %s, "id": %d}'
    , [web3.json.quoteString(method, '"'), formatArgs(args), id]);
end;

function send(const URL, method: string; args: array of const; callback: TAsyncResponse): IAsyncResult;
var
  client: THttpClient;
  source: TStream;
  resp  : TJsonObject;
  err   : TJsonObject;
begin
  try
    client := THttpClient.Create;
    source := TStringStream.Create(getPayload(method, args));
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := web3.json.unmarshal(THttpClient.EndAsyncHTTP(aSyncResult).ContentAsString(TEncoding.UTF8));
        if Assigned(resp) then
        try
          // did we receive an error? then translate that into an exception
          err := web3.json.getPropAsObj(resp, 'error');
          if Assigned(err) then
            callback(resp, EJsonRpc.Create(web3.json.getPropAsInt(err, 'code'), web3.json.getPropAsStr(err, 'message')))
          else
            // if we reached this far, then we have a valid response object
            callback(resp, nil);
        finally
          resp.Free;
        end;
      finally
        source.Free;
        client.Free;
      end;
    end, URL, source, nil, [TNetHeader.Create('Content-Type', 'application/json')]);
  except
    on E: Exception do
      callback(nil, E);
  end;
end;

function send(const URL, method: string; args: array of const): TJsonObject;
var
  client: THttpClient;
  source: TStream;
  err   : TJsonObject;
begin
  client := THttpClient.Create;
  source := TStringStream.Create(getPayload(method, args));
  try
    Result := web3.json.unmarshal(
      client.Post(URL, source, nil, [TNetHeader.Create('Content-Type', 'application/json')]).ContentAsString(TEncoding.UTF8)
    );
    if Assigned(Result) then
    begin
      // did we receive an error? then translate that into an exception
      err := web3.json.getPropAsObj(Result, 'error');
      if Assigned(err) then
        raise EJsonRpc.Create(web3.json.getPropAsInt(err, 'code'), web3.json.getPropAsStr(err, 'message'));
    end;
  finally
    source.Free;
    client.Free;
  end;
end;

end.
