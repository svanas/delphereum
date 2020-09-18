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

unit web3.eth.infura;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.http;

type
  EInfura = class(EWeb3);

function endpoint(chain: TChain; const projectId: string): string;

type
  ITicker = interface
    function Base        : string;   // Currency pair base
    function Quote       : string;   // Currency pair quote
    function Bid         : Extended; // Bid at the exchange with the most volume
    function Ask         : Extended; // Ask at the exchange with most volume
    function Volume      : Extended; // Volume at the exchange with the most volume
    function Exchange    : string;   // The exchange with the most volume
    function TotalVolume : Extended; // Total volume across all exchanges queried
    function NumExchanges: Integer;  // Number of exchanges queried
  end;

  TAsyncTicker = reference to procedure(ticker: ITicker; err: IError);

function ticker(const symbol: string; callback: TAsyncTicker): IAsyncResult; overload;
function ticker(const symbol: string; callback: TAsyncJsonObject): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.JSON,
  System.NetEncoding,
  System.SysUtils,
  System.TypInfo,
  // web3
  web3.json;

function endpoint(chain: TChain; const projectId: string): string;
const
  ENDPOINT: array[TChain] of string = (
    'https://mainnet.infura.io/v3/%s', // Mainnet
    'https://ropsten.infura.io/v3/%s', // Ropsten
    'https://rinkeby.infura.io/v3/%s', // Rinkeby
    'https://goerli.infura.io/v3/%s',  // Goerli
    '',                                // RSK_main_net
    '',                                // RSK_test_net
    'https://kovan.infura.io/v3/%s',   // Kovan
    ''                                 // Ganache
  );
begin
  Result := ENDPOINT[chain];
  if Result = '' then
    raise EInfura.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))])
  else
    Result := Format(Result, [projectId]);
end;

type
  TTicker = class(TInterfacedObject, ITicker)
  private
    FJsonObject: TJsonObject;
  public
    function Base        : string;
    function Quote       : string;
    function Bid         : Extended;
    function Ask         : Extended;
    function Volume      : Extended;
    function Exchange    : string;
    function TotalVolume : Extended;
    function NumExchanges: Integer;
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

function TTicker.Base: string;
begin
  Result := getPropAsStr(FJsonObject, 'base');
end;

function TTicker.Quote: string;
begin
  Result := getPropAsStr(FJsonObject, 'quote');
end;

function TTicker.Bid: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'bid');
end;

function TTicker.Ask: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'ask');
end;

function TTicker.Volume: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'volume');
end;

function TTicker.Exchange: string;
begin
  Result := getPropAsStr(FJsonObject, 'exchange');
end;

function TTicker.TotalVolume: Extended;
begin
  Result := getPropAsExt(FJsonObject, 'total_volume');
end;

function TTicker.NumExchanges: Integer;
begin
  Result := getPropAsInt(FJsonObject, 'num_exchanges');
end;

function ticker(const symbol: string; callback: TAsyncTicker): IAsyncResult;
begin
  Result := ticker(symbol, procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TTicker.Create(obj.Clone as TJsonObject), nil);
  end);
end;

function ticker(const symbol: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  Result := web3.http.get(
    'https://api.infura.io/v1/ticker/' + TNetEncoding.URL.Encode(symbol),
    callback
  );
end;

end.
