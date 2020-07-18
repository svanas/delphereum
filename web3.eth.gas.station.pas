{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.gas.station;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.eth.types;

type
  IGasPrice = interface
    function Fast   : TWei; // expected to be mined in < 2 minutes
    function Average: TWei; // expected to be mined in < 5 minutes
    function SafeLow: TWei; // expected to be mined in < 30 minutes
  end;

  TAsyncGasPrice = reference to procedure(price: IGasPrice; err: IError);

function getGasPrice(
  const apiKey: string;
  callback    : TAsyncGasPrice): IAsyncResult; overload;
function getGasPrice(
  const apiKey: string;
  callback    : TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  System.Net.HttpClient,
  System.NetEncoding,
  System.SysUtils,
  // web3
  web3.eth.utils,
  web3.json;

type
  TGasPrice = class(TInterfacedObject, IGasPrice)
  private
    FJsonObject: TJsonObject;
  public
    function Fast   : TWei;
    function Average: TWei;
    function SafeLow: TWei;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TGasPrice.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TGasPrice.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TGasPrice.Fast: TWei;
begin
  Result := toWei(FloatToEth(getPropAsExt(FJsonObject, 'fast') / 10), gwei);
end;

function TGasPrice.Average: TWei;
begin
  Result := toWei(FloatToEth(getPropAsExt(FJsonObject, 'average') / 10), gwei);
end;

function TGasPrice.SafeLow: TWei;
begin
  Result := toWei(FloatToEth(getPropAsExt(FJsonObject, 'safeLow') / 10), gwei);
end;

function getGasPrice(const apiKey: string; callback: TAsyncGasPrice): IAsyncResult;
begin
  Result := getGasPrice(apiKey, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TGasPrice.Create(obj.Clone as TJsonObject), nil);
  end);
end;

function getGasPrice(const apiKey: string; callback: TAsyncJsonObject): IAsyncResult;
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
    end, 'https://ethgasstation.info/api/ethgasAPI.json?api-key=' + TNetEncoding.URL.Encode(apiKey));
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

end.
