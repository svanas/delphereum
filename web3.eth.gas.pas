{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
{                                                                              }
{******************************************************************************}

unit web3.eth.gas;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.abi,
  web3.eth.gas.station,
  web3.eth.types,
  web3.json,
  web3.json.rpc,
  web3.utils;

procedure getGasPrice(client: IWeb3; callback: TAsyncQuantity);
procedure getBaseFeePerGas(client: IWeb3; callback: TAsyncQuantity);
procedure getMaxPriorityFeePerGas(client: IWeb3; callback: TAsyncQuantity);
procedure getMaxFeePerGas(client: IWeb3; callback: TAsyncQuantity);

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncQuantity); overload;
procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  &strict   : Boolean;
  callback  : TAsyncQuantity); overload;

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const data: string;
  callback  : TAsyncQuantity); overload;
procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const data: string;
  &strict   : Boolean;
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

  if client.TxType >= 2 then // EIP-1559
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
            callback(baseFee + tip, nil);
        end);
    end);
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
  var adjustForSpeed := function(tip: BigInteger; speed: TGasPrice): BigInteger
  begin
    case speed of
      Fastest: Result := TWei.Max(tip, 4000000000); // 4 Gwei
      Fast   : Result := TWei.Max(tip, 3000000000); // 3 Gwei
      Medium : Result := TWei.Max(tip, 2000000000); // 2 Gwei
      Low    : Result := 1000000000;                // 1 Gwei
    end;
  end;

  client.Call('eth_maxPriorityFeePerGas', [], procedure(resp: TJsonObject; err: IError)
  begin
    var info := client.GetGasStationInfo;

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
              callback(adjustForSpeed(TWei.Max(1000000000, gasPrice - baseFee), info.Speed), nil);
          end);
      end);
      EXIT;
    end;

    callback(adjustForSpeed(web3.json.getPropAsStr(resp, 'result'), info.Speed), nil);
  end);
end;

procedure getMaxFeePerGas(client: IWeb3; callback: TAsyncQuantity);
begin
  var info := client.GetGasStationInfo;

  if info.Custom > 0 then
  begin
    callback(info.Custom, nil);
    EXIT;
  end;

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
  callback  : TAsyncQuantity);
begin
  estimateGas(client, from, &to, func, args, False, callback);
end;

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const func: string;
  args      : array of const;
  &strict   : Boolean;
  callback  : TAsyncQuantity);
begin
  estimateGas(client, from, &to, web3.eth.abi.encode(func, args), &strict, callback);
end;

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const data: string;
  callback  : TAsyncQuantity);
begin
  estimateGas(client, from, &to, data, False, callback);
end;

procedure estimateGas(
  client    : IWeb3;
  from, &to : TAddress;
  const data: string;
  &strict   : Boolean;
  callback  : TAsyncQuantity);
begin
  // estimate how much gas is necessary for the transaction to complete (without creating a transaction on the blockchain)
  var eth_estimateGas := procedure(client: IWeb3; const json: string; callback: TAsyncQuantity)
  begin
    var obj := web3.json.unmarshal(json) as TJsonObject;
    try
      client.Call('eth_estimateGas', [obj], procedure(resp: TJsonObject; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(0, err);
          EXIT;
        end;
        callback(web3.json.getPropAsStr(resp, 'result'), nil);
      end);
    finally
      obj.Free;
    end;
  end;

  // if True, then factor in your gas price (otherwise ignore your gas price while estimating gas)
  if not &strict then
  begin
    eth_estimateGas(client, Format(
      '{"from": %s, "to": %s, "data": %s}',
      [quoteString(string(from), '"'), quoteString(string(&to), '"'), quoteString(data, '"')]
    ), callback);
    EXIT;
  end;

  // construct the eip-1559 transaction call object
  if client.TxType >= 2 then
  begin
    getMaxPriorityFeePerGas(client, procedure(tip: TWei; err: IError)
    begin
      if Assigned(err) then
        callback(0, err)
      else
        getMaxFeePerGas(client, procedure(max: TWei; err: IError)
        begin
          if Assigned(err) then
            callback(0, err)
          else
            eth_estimateGas(client, Format(
              '{"from": %s, "to": %s, "data": %s, "maxPriorityFeePerGas": %s, "maxFeePerGas": %s}', [
                web3.json.quoteString(string(from), '"'),
                web3.json.quoteString(string(&to), '"'),
                web3.json.quoteString(data, '"'),
                web3.json.quoteString(toHex(tip, [zeroAs0x0]), '"'),
                web3.json.quoteString(toHex(max, [zeroAs0x0]), '"')
              ]
            )
            , callback);
        end);
    end);
    EXIT;
  end;

  // construct the legacy transaction call object
  getGasPrice(client, procedure(gasPrice: TWei; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      eth_estimateGas(client, Format(
        '{"from": %s, "to": %s, "data": %s, "gasPrice": %s}', [
          web3.json.quoteString(string(from), '"'),
          web3.json.quoteString(string(&to), '"'),
          web3.json.quoteString(data, '"'),
          web3.json.quoteString(toHex(gasPrice, [zeroAs0x0]), '"')
        ]
      ), callback);
  end);
end;

end.
