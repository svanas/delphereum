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

unit web3.eth.rari.capital.api;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.http;

type
  IRariStats = interface
    function TVL          : Extended;
    function StablePoolAPY: Extended;
    function EthPoolAPY   : Extended;
    function YieldPoolAPY : Extended;
  end;

  TAsyncRariStats = reference to procedure(stats: IRariStats; err: IError);

function stats(callback: TAsyncRariStats) : IAsyncResult; overload;
function stats(callback: TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  // web3
  web3.json;

{--------------------------------- TRariStats ---------------------------------}

type
  TRariStats = class(TInterfacedObject, IRariStats)
  private
    FJsonObject: TJsonObject;
  public
    function TVL          : Extended;
    function StablePoolAPY: Extended;
    function EthPoolAPY   : Extended;
    function YieldPoolAPY : Extended;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TRariStats.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TRariStats.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TRariStats.TVL: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'tvl');
end;

function TRariStats.StablePoolAPY: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'stablePoolAPY');
end;

function TRariStats.EthPoolAPY: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'ethPoolAPY');
end;

function TRariStats.YieldPoolAPY: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'yieldPoolAPY');
end;

{------------------------------ global functions ------------------------------}

function stats(callback: TAsyncRariStats) : IAsyncResult;
begin
  Result := stats(procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TRariStats.Create(obj.Clone as TJsonObject), nil);
  end);
end;

function stats(callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get('https://v2.rari.capital/api/stats', callback);
end;

end.
