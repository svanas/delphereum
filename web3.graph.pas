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
  System.Types,
  // web3
  web3,
  web3.http;

type
  IGraphError = interface(IError)
  ['{46F0E07F-F47C-41BC-98BF-B8F7FA24AB91}']
  end;

  TGraphError = class(TError, IGraphError);

const
  UNISWAP_V2 = 'https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v2';

function execute(const URL, query: string; callback: TAsyncJsonObject): IAsyncResult;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Net.URLClient,
  // web3
  web3.json;

function execute(const URL, query: string; callback: TAsyncJsonObject): IAsyncResult;
begin
  web3.http.post(
    URL,
    query,
    [TNetHeader.Create('Content-Type', 'application/graphql')],
    procedure(resp: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      // did we receive an error?
      var errors := web3.json.getPropAsArr(resp, 'errors');
      if Assigned(errors) and (errors.Count > 0) then
      begin
        callback(resp, TGraphError.Create(web3.json.getPropAsStr(errors.Items[0], 'message')));
        EXIT;
      end;
      // if we reached this far, then we have a valid response object
      callback(resp, nil);
    end
  );
end;

end.
