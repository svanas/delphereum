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
  web3.json.rpc,
  web3.types;

procedure getGasPrice(client: TWeb3; callback: TASyncQuantity);

procedure estimateGas(client: TWeb3; &to: TAddress;
  const func: string; args: array of const; callback: TASyncQuantity); overload;
procedure estimateGas(client: TWeb3; from, &to: TAddress;
  const func: string; args: array of const; callback: TASyncQuantity); overload;

implementation

procedure getGasPrice(client: TWeb3; callback: TASyncQuantity);
begin
  web3.json.rpc.send(client.URL, 'eth_gasPrice', [], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.GetPropAsStr(resp, 'result'), nil);
  end);
end;

procedure estimateGas(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TASyncQuantity);
begin
  estimateGas(client, ADDRESS_ZERO, &to, func, args, callback);
end;

procedure estimateGas(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TASyncQuantity);
var
  abi: string;
  obj: TJsonObject;
begin
  // step #1: encode the function abi
  abi := web3.eth.abi.encode(func, args);
  // step #2: construct the transaction call object
  obj := web3.json.unmarshal(Format(
    '{"from": %s, "to": %s, "data": %s}', [
      web3.json.QuoteString(string(from), '"'),
      web3.json.QuoteString(string(&to), '"'),
      web3.json.QuoteString(abi, '"')
    ]
  ));
  try
    // step #3: estimate how much gas is necessary for the transaction to complete (without creating a transaction on the blockchain)
    web3.json.rpc.send(client.URL, 'eth_estimateGas', [obj], procedure(resp: TJsonObject; err: Exception)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        callback(web3.json.GetPropAsStr(resp, 'result'), nil);
    end);
  finally
    obj.Free;
  end;
end;

end.
