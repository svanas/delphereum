unit web3.json.rpc;

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
  web3.json;

type
  EJsonRpc = class(Exception)
  private
    FCode: Integer;
  public
    constructor Create(aCode: Integer; const aMsg: string);
    property Code: Integer read FCode;
  end;

type
  TASyncResponse = reference to procedure(resp: TJsonObject; err: Exception);

function Send(const URL, method: string; args: array of const; callback: TASyncResponse): IASyncResult;

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

function FormatArgs(args: array of const): string;
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
          Result := Result + QuoteString(UnicodeString(PShortString(arg.VAnsiString)^), '"');
        vtObject:
          Result := Result + web3.json.Marshal(arg.VObject as TJsonObject);
        vtWideString:
          Result := Result + QuoteString(WideString(arg.VWideString^), '"');
        vtInt64:
          Result := Result + '0x' + IntToHex(arg.VInt64^, 0);
        vtUnicodeString:
          Result := Result + QuoteString(string(arg.VUnicodeString), '"');
      end;
    end;
  finally
    Result := Result + ']';
  end;
end;

function GetPayload(const method: string; args: array of const): string;
begin
  Inc(id);
  Result := Format(
    '{"jsonrpc": "2.0", "method": %s, "params": %s, "id": %d}'
    , [web3.json.QuoteString(method, '"'), FormatArgs(args), id]);
end;

function Send(const URL, method: string; args: array of const; callback: TASyncResponse): IASyncResult;
var
  client: THttpClient;
  source: TStream;
  resp  : TJsonObject;
  err   : TJsonObject;
begin
  try
    client := THttpClient.Create;
    source := TStringStream.Create(GetPayload(method, args));
    Result := client.BeginPost(procedure(const aSyncResult: IASyncResult)
    begin
      try
        resp := web3.json.Unmarshal(THttpClient.EndAsyncHTTP(aSyncResult).ContentAsString(TEncoding.UTF8));
        if Assigned(resp) then
        try
          // did we receive an error? then translate that into an exception
          err := web3.json.GetPropAsObj(resp, 'error');
          if Assigned(err) then
            callback(resp, EJsonRpc.Create(web3.json.GetPropAsInt(err, 'code'), web3.json.GetPropAsStr(err, 'message')))
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

end.
