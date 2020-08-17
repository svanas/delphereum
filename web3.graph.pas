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

unit web3.graph;

{$I web3.inc}

interface

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.SysUtils,
  System.Types,
  // web3
  web3,
  web3.json;

type
  IGraphQL = interface(IError)
  ['{46F0E07F-F47C-41BC-98BF-B8F7FA24AB91}']
  end;

  TGraphQL = class(TError, IGraphQL);

  TAsyncResponse = reference to procedure(resp: TJsonObject; err: IError);

const
  UNISWAP_V2 = 'https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v2';

function execute(const URL, query: string; callback: TAsyncResponse): IAsyncResult;

implementation

function execute(const URL, query: string; callback: TAsyncResponse): IAsyncResult;
var
  client: THttpClient;
  source: TStream;
  resp  : TJsonObject;
  errors: TJsonArray;
begin
  try
    client := THttpClient.Create;
    source := TStringStream.Create(query);
    Result := client.BeginPost(procedure(const aSyncResult: IAsyncResult)
    begin
      try
        resp := web3.json.unmarshal(THttpClient.EndAsyncHTTP(aSyncResult).ContentAsString(TEncoding.UTF8));
        if Assigned(resp) then
        try
          // did we receive an error?
          errors := web3.json.getPropAsArr(resp, 'errors');
          if Assigned(errors) then
            if errors.Count > 0 then
            begin
              callback(resp, TGraphQL.Create(web3.json.getPropAsStr(errors.Items[0], 'message')));
              EXIT;
            end;
          // if we reached this far, then we have a valid response object
          callback(resp, nil);
        finally
          resp.Free;
        end;
      finally
        source.Free;
        client.Free;
      end;
    end, URL, source, nil, [TNetHeader.Create('Content-Type', 'application/graphql')]);
  except
    on E: Exception do
      callback(nil, TError.Create(E.Message));
  end;
end;

end.
