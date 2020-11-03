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

unit web3.coincap;

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.http;

type
  ITicker = interface
    function Symbol: string;   // most common symbol used to identify this asset on an exchange
    function Price : Extended; // volume-weighted price based on real-time market data, translated to USD
  end;

  TAsyncTicker = reference to procedure(ticker: ITicker; err: IError);

function ticker(const asset: string; callback: TAsyncTicker): IAsyncResult; overload;
function ticker(const asset: string; callback: TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  System.NetEncoding,
  // web3
  web3.json;

type
  TTicker = class(TInterfacedObject, ITicker)
  private
    FJsonObject: TJsonObject;
  public
    function Symbol: string;
    function Price : Extended;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TTicker.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TTicker.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TTicker.Symbol: string;
begin
  Result := getPropAsStr(FJsonObject, 'symbol');
end;

function TTicker.Price: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'priceUsd');
end;

function ticker(const asset: string; callback: TAsyncTicker): IAsyncResult;
begin
  Result := ticker(asset, procedure(obj: TJsonObject; err: IError)
  var
    data: TJsonObject;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    data := getPropAsObj(obj, 'data');
    if not Assigned(data) then
    begin
      callback(nil, TError.Create('%s.data is null', [asset]));
      EXIT;
    end;
    callback(TTicker.Create(data.Clone as TJsonObject), nil);
  end);
end;

function ticker(const asset: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get(
    'https://api.coincap.io/v2/assets/' + TNetEncoding.URL.Encode(asset),
    callback
  );
end;

end.
