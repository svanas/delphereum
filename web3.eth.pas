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

unit web3.eth;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

const
  BLOCK_EARLIEST = 'earliest';
  BLOCK_LATEST   = 'latest';
  BLOCK_PENDING  = 'pending';

const
  BLOCKS_PER_DAY = 5760; // 4 * 60 * 24

const
  EMPTY_ADDRESS: TAddress = '0x0000000000000000000000000000000000000000';
  EMPTY_BYTES32: TBytes32 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

function  blockNumber(client: IWeb3): BigInteger; overload;               // blocking
procedure blockNumber(client: IWeb3; callback: TAsyncQuantity); overload; // async

procedure getBlockByNumber(client: IWeb3; callback: TAsyncBlock); overload;
procedure getBlockByNumber(client: IWeb3; const block: string; callback: TAsyncBlock); overload;

procedure getBalance(client: IWeb3; address: TAddress; callback: TAsyncQuantity); overload;
procedure getBalance(client: IWeb3; address: TAddress; const block: string; callback: TAsyncQuantity); overload;

procedure getTransactionCount(client: IWeb3; address: TAddress; callback: TAsyncQuantity); overload;
procedure getTransactionCount(client: IWeb3; address: TAddress; const block: string; callback: TAsyncQuantity); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncString); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncString); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncBytes32); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncBytes32); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBytes32); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBytes32); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple); overload;

function  sign(privateKey: TPrivateKey; const msg: string): TSignature; overload;
procedure sign(client: IWeb3; from: TPrivateKey; &to: TAddress; value: TWei; const data: string; estimatedGas: BigInteger; callback: TAsyncString); overload;

// transact with a non-payable function.
// default to the median gas price from the latest blocks.
// gas limit is twice the estimated gas.
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncTxHash); overload;
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt); overload;

// transact with a payable function.
// default to the median gas price from the latest blocks.
// gas limit is twice the estimated gas.
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TAsyncTxHash); overload;
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt); overload;

procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TAsyncTxHash); overload;
procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TAsyncReceipt); overload;

implementation

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // CryptoLib4Pascal
  ClpBigInteger,
  ClpIECPrivateKeyParameters,
  // web3
  web3.crypto,
  web3.eth.abi,
  web3.eth.crypto,
  web3.eth.gas,
  web3.eth.tx,
  web3.json,
  web3.json.rpc,
  web3.utils;

function blockNumber(client: IWeb3): BigInteger;
var
  obj: TJsonObject;
begin
  obj := client.Call('eth_blockNumber', []);
  if Assigned(obj) then
  try
    Result := web3.json.getPropAsStr(obj, 'result');
  finally
    obj.Free;
  end;
end;

procedure blockNumber(client: IWeb3; callback: TAsyncQuantity);
begin
  client.Call('eth_blockNumber', [], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

type
  TBlock = class(TInterfacedObject, IBlock)
  private
    FJsonObject: TJsonObject;
  public
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
    function ToString: string; override;
    function baseFeePerGas: TWei;
  end;

constructor TBlock.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject.Clone as TJsonObject;
end;

destructor TBlock.Destroy;
begin
  if Assigned(FJsonObject) then FJsonObject.Free;
  inherited Destroy;
end;

function TBlock.ToString: string;
begin
  Result := web3.json.marshal(FJsonObject);
end;

function TBlock.baseFeePerGas: TWei;
begin
  Result := getPropAsStr(FJsonObject, 'baseFeePerGas', '0x0');
end;

procedure getBlockByNumber(client: IWeb3; callback: TAsyncBlock);
begin
  getBlockByNumber(client, BLOCK_PENDING, callback);
end;

procedure getBlockByNumber(client: IWeb3; const block: string; callback: TAsyncBlock);
begin
  client.Call('eth_getBlockByNumber', [block, False], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TBlock.Create(web3.json.getPropAsObj(resp, 'result')), nil);
  end);
end;

procedure getBalance(client: IWeb3; address: TAddress; callback: TAsyncQuantity);
begin
  getBalance(client, address, BLOCK_LATEST, callback);
end;

procedure getBalance(client: IWeb3; address: TAddress; const block: string; callback: TAsyncQuantity);
begin
  client.Call('eth_getBalance', [address, block], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure getTransactionCount(client: IWeb3; address: TAddress; callback: TAsyncQuantity);
begin
  getTransactionCount(client, address, BLOCK_LATEST, callback);
end;

// returns the number of transations *sent* from an address
procedure getTransactionCount(client: IWeb3; address: TAddress; const block: string; callback: TAsyncQuantity);
begin
  client.Call('eth_getTransactionCount', [address, block], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncString);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncString);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString);
var
  abi: string;
  obj: TJsonObject;
begin
  // step #1: encode the function abi
  abi := web3.eth.abi.encode(func, args);
  // step #2: construct the transaction call object
  obj := web3.json.unmarshal(Format(
    '{"from": %s, "to": %s, "data": %s}', [
      web3.json.quoteString(string(from), '"'),
      web3.json.quoteString(string(&to), '"'),
      web3.json.quoteString(abi, '"')
    ]
  )) as TJsonObject;
  try
    // step #3: execute a message call (without creating a transaction on the blockchain)
    client.Call('eth_call', [obj, block], procedure(resp: TJsonObject; err: IError)
    begin
      if Assigned(err) then
        callback('', err)
      else
        callback(web3.json.getPropAsStr(resp, 'result'), nil);
    end);
  finally
    obj.Free;
  end;
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: IError)
  var
    buf: TBytes;
  begin
    if Assigned(err) then
      callback(0, err)
    else
      if (hex = '') or (hex.ToLower = '0x') then
        callback(0, nil)
      else
      begin
        buf := web3.utils.fromHex(hex);
        if Length(buf) <= 32 then
          callback(hex, nil)
        else
          callback(web3.utils.toHex(Copy(buf, 0, 32)), nil);
      end;
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: IError)
  var
    buf: TBytes;
  begin
    if Assigned(err) then
      callback(False, err)
    else
    begin
      buf := web3.utils.fromHex(hex);
      callback((Length(buf) > 0) and (buf[High(buf)] <> 0), nil);
    end;
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncBytes32);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncBytes32);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBytes32);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBytes32);
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: IError)
  var
    buffer: TBytes;
    result: TBytes32;
  begin
    if Assigned(err) then
    begin
      callback(EMPTY_BYTES32, err);
      EXIT;
    end;
    buffer := web3.utils.fromHex(hex);
    if Length(buffer) < 32 then
    begin
      callback(EMPTY_BYTES32, nil);
      EXIT;
    end;
    Move(buffer[0], result[0], 32);
    callback(result, nil);
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback([], err)
    else
      callback(TTuple.From(hex), nil);
  end);
end;

function sign(privateKey: TPrivateKey; const msg: string): TSignature;
var
  Signer   : TEthereumSigner;
  Signature: TECDsaSignature;
  v        : TBigInteger;
begin
  Signer := TEthereumSigner.Create;
  try
    Signer.Init(True, privateKey.Parameters);
    Signature := Signer.GenerateSignature(
      sha3(
        TEncoding.UTF8.GetBytes(
          #25 + 'Ethereum Signed Message:' + #10 + IntToStr(Length(msg)) + msg
        )
      )
    );
    v := Signature.rec.Add(TBigInteger.ValueOf(27));
    Result := TSignature(
      toHex(
        Signature.r.ToByteArrayUnsigned +
        Signature.s.ToByteArrayUnsigned +
        v.ToByteArrayUnsigned
      )
    );
  finally
    Signer.Free;
  end;
end;

procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncTxHash);
begin
  write(client, from, &to, 0, func, args, callback);
end;

procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt);
begin
  write(client, from, &to, 0, func, args, callback);
end;

procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TAsyncTxHash);
begin
  var data := web3.eth.abi.encode(func, args);
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.gas.estimateGas(client, addr, &to, data, procedure(estimatedGas: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback('', err)
        else
          write(client, from, &to, value, data, estimatedGas, callback);
      end);
  end);
end;

procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt);
begin
  var data := web3.eth.abi.encode(func, args);
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.gas.estimateGas(client, addr, &to, data, procedure(estimatedGas: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          write(client, from, &to, value, data, estimatedGas, callback);
      end);
  end);
end;

procedure sign(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TAsyncString);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.tx.getNonce(client, addr, procedure(nonce: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback('', err)
        else
          signTransaction(client, nonce, from, &to, value, data, 2 * estimatedGas, estimatedGas, callback);
      end);
  end);
end;

procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TAsyncTxHash);
begin
  sign(client, from, &to, value, data, estimatedGas, procedure(const sig: string; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      sendTransaction(client, sig, procedure(hash: TTxHash; err: IError)
      begin
        if Assigned(err) and (err.Message = 'nonce too low') then
          write(client, from, &to, value, data, estimatedGas, callback)
        else
          callback(hash, err);
      end);
  end);
end;

procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TAsyncReceipt);
begin
  sign(client, from, &to, value, data, estimatedGas, procedure(const sig: string; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      sendTransaction(client, sig, procedure(rcpt: ITxReceipt; err: IError)
      begin
        if Assigned(err) and (err.Message = 'nonce too low') then
          write(client, from, &to, value, data, estimatedGas, callback)
        else
          callback(rcpt, err);
      end);
  end);
end;

end.
