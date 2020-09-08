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

unit web3.eth.etherscan;

{$I web3.inc}

interface

uses
  // Delphi
  System.Types,
  // web3
  web3,
  web3.eth.types;

type
  EEtherscan = class(EWeb3);

  IEtherscanError = interface(IError)
  ['{4AAD53A6-FBD8-4FAB-83F7-6FDE0524CE5C}']
    function Status: Integer;
  end;

  TEtherscanError = class(TError, IEtherscanError)
  private
    FStatus: Integer;
  public
    constructor Create(aStatus: Integer; const aMsg: string);
    function Status: Integer;
  end;

function getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TAsyncQuantity): IAsyncResult;

implementation

uses
  // Delphi
  System.JSON,
  System.Net.HttpClient,
  System.NetEncoding,
  System.SysUtils,
  System.TypInfo,
  // web3
  web3.json;

function endpoint(chain: TChain; const apiKey: string): string;
const
  ENDPOINT: array[TChain] of string = (
    'https://api.etherscan.io/api?apikey=%s',         // Mainnet
    'https://api-ropsten.etherscan.io/api?apikey=%s', // Ropsten
    'https://api-rinkeby.etherscan.io/api?apikey=%s', // Rinkeby
    'https://api-goerli.etherscan.io/api?apikey=%s',  // Goerli
    '',                                               // RSK_main_net
    '',                                               // RSK_test_net
    'https://api-kovan.etherscan.io/api?apikey=%s',   // Kovan
    ''                                                // Ganache
  );
begin
  Result := ENDPOINT[chain];
  if Result = '' then
    raise EEtherscan.CreateFmt('%s not supported', [GetEnumName(TypeInfo(TChain), Ord(chain))])
  else
    Result := Format(Result, [apiKey]);
end;

{ TEtherscanError }

constructor TEtherscanError.Create(aStatus: Integer; const aMsg: string);
begin
  inherited Create(aMsg);
  FStatus := aStatus;
end;

function TEtherscanError.Status: Integer;
begin
  Result := FStatus;
end;

{ global functions }

function getBlockNumberByTimestamp(
  chain       : TChain;
  timestamp   : TUnixDateTime;
  const apiKey: string;
  callback    : TAsyncQuantity): IAsyncResult;
var
  client: THttpClient;
  resp  : IHttpResponse;
  output: TJsonObject;
  status: Integer;
begin
  try
    client := THttpClient.Create;
    Result := client.BeginGet(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := THttpClient.EndAsyncHttp(aSyncResult);
        if resp.StatusCode = 200 then
        begin
          output := web3.json.unmarshal(resp.ContentAsString(TEncoding.UTF8));
          if Assigned(output) then
          try
            status := web3.json.getPropAsInt(output, 'status');
            if status = 0 then
              callback(0, TEtherscanError.Create(status, web3.json.getPropAsStr(output, 'message')))
            else
              callback(web3.json.getPropAsBig(output, 'result', 0), nil);
            EXIT;
          finally
            output.Free;
          end;
        end;
        callback(0, TError.Create(resp.ContentAsString(TEncoding.UTF8)));
      finally
        client.Free;
      end;
    end, endpoint(chain, TNetEncoding.URL.Encode(apiKey)) + Format('&module=block&action=getblocknobytime&timestamp=%d&closest=before', [timestamp]));
  except
    on E: Exception do
      callback(0, TError.Create(E.Message));
  end;
end;

end.
