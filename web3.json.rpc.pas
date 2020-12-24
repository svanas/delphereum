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
  System.SysUtils,
  // web3
  web3,
  web3.json,
  web3.sync;

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

  TCustomJsonRpc = class abstract(TInterfacedObject, IProtocol, IJsonRpc)
  strict private
    class var
      _ID: ICriticalInt64;
  strict protected
    class function ID: ICriticalInt64;
    class function FormatArgs(args: array of const): string;

    class function GetPayload(
      const method: string;
      args        : array of const): string; overload;
    class function GetPayload(
      ID          : Int64;
      const method: string;
      args        : array of const): string; overload;
  public
    function Send(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): TJsonObject; overload; virtual; abstract;
    procedure Send(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const;
      callback    : TAsyncJsonObject); overload; virtual; abstract;
  end;

implementation

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

{ TCustomJsonRpc }

class function TCustomJsonRpc.ID: ICriticalInt64;
begin
  if not Assigned(_ID) then
    _ID := TCriticalInt64.Create(0);
  Result := _ID;
end;

class function TCustomJsonRpc.FormatArgs(args: array of const): string;
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
          Result := Result + web3.json.marshal(arg.VObject as TJsonValue);
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

class function TCustomJsonRpc.GetPayload(const method: string; args: array of const): string;
begin
  ID.Enter;
  try
    Result := GetPayload(ID.Inc, method, args);
  finally
    ID.Leave;
  end;
end;

class function TCustomJsonRpc.GetPayload(ID: Int64; const method: string; args: array of const): string;
begin
  Result := Format(
    '{"jsonrpc": "2.0", "method": %s, "params": %s, "id": %d}',
    [web3.json.quoteString(method, '"'), FormatArgs(args), ID]
  );
end;

end.
