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

unit web3;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils;

type
  EWeb3 = class(Exception);

type
  TWeb3 = record
    var
      URL: string;
    class function New(const aURL: string): TWeb3; static;
  end;

implementation

class function TWeb3.New(const aURL: string): TWeb3;
begin
  Result.URL := aURL;
end;

end.
