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

procedure getGasPrice(client: IWeb3; callback: TAsyncQuantity);
procedure getBaseFeePerGas(client: IWeb3; callback: TAsyncQuantity);
procedure getMaxPriorityFeePerGas(client: IWeb3; callback: TAsyncQuantity);
procedure getMaxFeePerGas(client: IWeb3; callback: TAsyncQuantity);

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  default   : TWei;
  callback  : TAsyncQuantity); overload;
procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const data: string;
  default   : TWei;
  callback  : TAsyncQuantity); overload;

implementation

procedure eth_gasPrice(client: IWeb3; callback: TAsyncQuantity);
begin
  client.Call('eth_gasPrice', [], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure getGasPrice(client: IWeb3; callback: TAsyncQuantity);
begin
  var info := client.GetGasStationInfo;

  if info.Custom > 0 then
  begin
    callback(info.Custom, nil);
    EXIT;
  end;

  if (info.apiKey = '') and (info.Speed = Medium) then
  begin
    eth_gasPrice(client, callback);
    EXIT;
  end;

  web3.eth.gas.station.getGasPrice(info.apiKey, procedure(price: IGasPrice; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      case info.Speed of
        Fastest: callback(price.Fastest, nil);
        Fast   : callback(price.Fast,    nil);
        Medium : callback(price.Average, nil);
        Low    : callback(price.SafeLow, nil);
      end;
  end);
end;

procedure getBaseFeePerGas(client: IWeb3; callback: TAsyncQuantity);
begin
  web3.eth.getBlockByNumber(client, procedure(block: IBlock; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(block.baseFeePerGas, nil);
  end);
end;

procedure getMaxPriorityFeePerGas(client: IWeb3; callback: TAsyncQuantity);
begin
  client.Call('eth_maxPriorityFeePerGas', [], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      eth_gasPrice(client, procedure(gasPrice: TWei; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          getBaseFeePerGas(client, procedure(baseFee: TWei; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(TWei.Max(1000000000, gasPrice - baseFee), nil);
          end);
      end);
      EXIT;
    end;
    callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure getMaxFeePerGas(client: IWeb3; callback: TAsyncQuantity);
begin
  getBaseFeePerGas(client, procedure(baseFee: TWei; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      getMaxPriorityFeePerGas(client, procedure(tip: TWei; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          callback((2 * baseFee) + tip, nil);
      end);
  end);
end;

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  default   : TWei;
  callback  : TAsyncQuantity);
begin
  estimateGas(client, from, &to, web3.eth.abi.encode(func, args), default, callback);
end;

procedure estimateGas(
  client    : IWeb3;
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
    client.Call('eth_estimateGas', [obj], procedure(resp: TJsonObject; err: IError)
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
