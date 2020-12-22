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
  // web3
  web3,
  web3.eth,
  web3.eth.abi,
  web3.eth.gas.station,
  web3.eth.types,
  web3.json,
  web3.json.rpc;

procedure getGasPrice(client: TWeb3; callback: TAsyncQuantity);

procedure estimateGas(
  client    : TWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  default   : TWei;
  callback  : TAsyncQuantity); overload;
procedure estimateGas(
  client    : TWeb3;
  from, &to : TAddress;
  const data: string;
  default   : TWei;
  callback  : TAsyncQuantity); overload;

implementation

procedure getGasPrice(client: TWeb3; callback: TAsyncQuantity);
begin
  client.GetGasStationInfo(procedure(gasInfo: TGasStationInfo)
  begin
    if gasInfo.Custom > 0 then
    begin
      callback(gasInfo.Custom, nil);
      EXIT;
    end;

    if (gasInfo.apiKey = '') and (gasInfo.Speed = Average) then
    begin
      client.JsonRpc.Send(client.URL, client.Security, 'eth_gasPrice', [], procedure(resp: TJsonObject; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback(web3.json.getPropAsStr(resp, 'result'), nil);
      end);
      EXIT;
    end;

    web3.eth.gas.station.getGasPrice(gasInfo.apiKey, procedure(price: IGasPrice; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        case gasInfo.Speed of
          Outbid : callback(price.Outbid,  nil);
          Fastest: callback(price.Fastest, nil);
          Fast   : callback(price.Fast,    nil);
          Average: callback(price.Average, nil);
          SafeLow: callback(price.SafeLow, nil);
        end;
    end);
  end);
end;

procedure estimateGas(
  client    : TWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  default   : TWei;
  callback  : TAsyncQuantity);
begin
  estimateGas(client, from, &to, web3.eth.abi.encode(func, args), default, callback);
end;

procedure estimateGas(
  client    : TWeb3;
  from, &to : TAddress;
  const data: string;
  default   : TWei;
  callback  : TAsyncQuantity);
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
  )) as TJsonObject;
  try
    // estimate how much gas is necessary for the transaction to complete (without creating a transaction on the blockchain)
    client.JsonRpc.Send(client.URL, client.Security, 'eth_estimateGas', [obj], procedure(resp: TJsonObject; err: IError)
    begin
      if Assigned(err) then
      begin
        if err.Message.Contains('gas required exceeds allowance') and (default > 0) then
          callback(default, nil)
        else
          callback(0, err);
        EXIT;
      end;
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
    end);
  finally
    obj.Free;
  end;
end;

end.
