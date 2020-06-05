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
  web3.eth,
  web3.eth.abi,
  web3.eth.types,
  web3.json,
  web3.json.rpc;

procedure getGasPrice(client: TWeb3; callback: TAsyncQuantity);

procedure estimateGas(client: TWeb3; from, &to: TAddress;
  const func: string; args: array of const; callback: TAsyncQuantity); overload;
procedure estimateGas(client: TWeb3; from, &to: TAddress;
  const data: string; callback: TAsyncQuantity); overload;

implementation

procedure getGasPrice(client: TWeb3; callback: TAsyncQuantity);
begin
  web3.json.rpc.send(client.URL, 'eth_gasPrice', [], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure estimateGas(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity);
begin
  estimateGas(client, from, &to, web3.eth.abi.encode(func, args), callback);
end;

procedure estimateGas(client: TWeb3; from, &to: TAddress; const data: string; callback: TAsyncQuantity);
var
  obj: TJsonObject;
begin
  // construct the transaction call object
  obj := web3.json.unmarshal(Format(
    '{"from": %s, "to": %s, "data": %s}', [
      web3.json.quoteString(string(from), '"'),
      web3.json.quoteString(string(&to), '"'),
      web3.json.quoteString(data, '"')
    ]
  ));
  try
    // estimate how much gas is necessary for the transaction to complete (without creating a transaction on the blockchain)
    web3.json.rpc.send(client.URL, 'eth_estimateGas', [obj], procedure(resp: TJsonObject; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(web3.json.getPropAsStr(resp, 'result'), nil);
    end);
  finally
    obj.Free;
  end;
end;

end.
