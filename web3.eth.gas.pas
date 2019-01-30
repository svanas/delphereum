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

unit web3.eth.gas;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Web3
  web3,
  web3.json,
  web3.json.rpc,
  web3.types;

procedure getGasPrice(client: TWeb3; callback: TASyncQuantity);

implementation

procedure getGasPrice(client: TWeb3; callback: TASyncQuantity);
begin
  web3.json.rpc.Send(client.URL, 'eth_gasPrice', [], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.GetPropAsStr(resp, 'result'), nil);
  end);
end;

end.
