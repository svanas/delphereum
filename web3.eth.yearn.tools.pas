{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{                             https://yearn.tools/                             }
{                                                                              }
{******************************************************************************}

unit web3.eth.yearn.tools;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.eth.defi,
  web3.http;

type
  IYearnVault = interface
    function Name       : string;
    function Symbol     : string;
    function Description: string;
    function APY(perform: TPerformance): Extended;
  end;

  TAsyncYearnVault = reference to procedure(apy: IYearnVault; err: IError);

function vault(const addr: TAddress; callback: TAsyncYearnVault): IAsyncResult; overload;
function vault(const addr: TAddress; callback: TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  // web3
  web3.json;

type
  TYearnVault = class(TInterfacedObject, IYearnVault)
  private
    FJsonObject: TJsonObject;
  public
    function Name       : string;
    function Symbol     : string;
    function Description: string;
    function APY(perform: TPerformance): Extended;
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
  end;

constructor TYearnVault.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject;
end;

destructor TYearnVault.Destroy;
begin
  if Assigned(FJsonObject) then
    FJsonObject.Free;
  inherited Destroy;
end;

function TYearnVault.Name: string;
begin
  Result := getPropAsStr(FJsonObject, 'name');
end;

function TYearnVault.Symbol: string;
begin
  Result := getPropAsStr(FJsonObject, 'vaultSymbol');
end;

function TYearnVault.Description: string;
begin
  Result := getPropAsStr(FJsonObject, 'description');
end;

function TYearnVault.APY(perform: TPerformance): Extended;
const
  PROP_NAME: array[TPerformance] of string = (
    'apyOneDaySample',   // oneDay
    'apyThreeDaySample', // threeDays
    'apyOneWeekSample',  // oneWeek
    'apyOneMonthSample'  // oneMonth
  );
begin
  Result := getPropAsExt(FJsonObject, PROP_NAME[perform])
end;

function vault(const addr: TAddress; callback: TAsyncYearnVault): IAsyncResult;
begin
  Result := vault(addr, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TYearnVault.Create(obj.Clone as TJsonObject), nil);
  end);
end;

function vault(const addr: TAddress; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get(
    'https://api.yearn.tools/vaults/apy',
  procedure(arr: TJsonArray; err: IError)
  var
    idx : Integer;
    elem: TJsonValue;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    for idx := 0 to Pred(arr.Count) do
    begin
      elem := TJsonArray(arr).Items[idx];
      if SameText(getPropAsStr(elem, 'address'), string(addr)) then
      begin
        callback(elem as TJsonObject, nil);
        EXIT;
      end;
    end;
    callback(nil, TError.Create('%s not found', [addr]));
  end);
end;

end.
