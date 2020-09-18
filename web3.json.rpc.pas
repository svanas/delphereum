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
  System.JSON,
  System.Types,
  // web3
  web3,
  web3.http;

type
  EJsonRpc = class(EWeb3)
  private
    FCode: Integer;
  public
    constructor Create(aCode: Integer; const aMsg: string);
    property Code: Integer read FCode;
  end;

  IJsonRpcError = interface(IError)
  ['{CA68D639-A1CF-458F-B2BF-70E5F947DD41}']
    function Code: Integer;
  end;

  TJsonRpcError = class(TError, IJsonRpcError)
  private
    FCode: Integer;
  public
    constructor Create(aCode: Integer; const aMsg: string);
    function Code: Integer;
  end;

function send( // async
  const URL   : string;
  const method: string;
  args        : array of const;
  callback    : TAsyncJsonObject): IAsyncResult; overload;

function send( // blocking
  const URL   : string;
  const method: string;
  args        : array of const): TJsonObject; overload;

implementation

uses
  // Delphi
  System.Classes,
  System.Net.URLClient,
  System.SysUtils,
  // web3
  web3.json;

var
  id: Cardinal;

{ EJsonRpc }

constructor EJsonRpc.Create(aCode: Integer; const aMsg: string);
begin
  inherited Create(aMsg);
  FCode := aCode;
end;

{ TJsonRpcError }

constructor TJsonRpcError.Create(aCode: Integer; const aMsg: string);
begin
  inherited Create(aMsg);
  FCode := aCode;
end;

function TJsonRpcError.Code: Integer;
begin
   Result := FCode;
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

function send(
  const URL   : string;
  const method: string;
  args        : array of const;
  callback    : TAsyncJsonObject): IAsyncResult;
var
  source: TStream;
begin
  source := TStringStream.Create(getPayload(method, args));
  web3.http.post(
    URL,
    source,
    [TNetHeader.Create('Content-Type', 'application/json')],
    procedure(resp: TJsonObject; err: IError)
  var
    error: TJsonObject;
  begin
    try
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      // did we receive an error?
      error := web3.json.getPropAsObj(resp, 'error');
      if Assigned(error) then
        callback(resp, TJsonRpcError.Create(
          web3.json.getPropAsInt(error, 'code'),
          web3.json.getPropAsStr(error, 'message')
        ))
      else
        // if we reached this far, then we have a valid response object
        callback(resp, nil);
    finally
      source.Free;
    end;
  end);
end;

function send(const URL, method: string; args: array of const): TJsonObject;
var
  source: TStream;
  resp  : TJsonObject;
  error : TJsonObject;
begin
  Result := nil;
  source := TStringStream.Create(getPayload(method, args));
  try
    web3.http.post(
      URL,
      source,
      [TNetHeader.Create('Content-Type', 'application/json')],
      resp
    );
    if Assigned(resp) then
    try
      // did we receive an error? then translate that into an exception
      error := web3.json.getPropAsObj(resp, 'error');
      if Assigned(error) then
        raise EJsonRpc.Create(
          web3.json.getPropAsInt(error, 'code'),
          web3.json.getPropAsStr(error, 'message')
        );
      Result := resp.Clone as TJsonObject;
    finally
      resp.Free;
    end;
  finally
    source.Free;
  end;
end;

end.
