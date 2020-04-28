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

unit web3.eth;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // Web3
  web3,
  web3.eth.types;

const
  BLOCK_EARLIEST = 'earliest';
  BLOCK_LATEST   = 'latest';
  BLOCK_PENDING  = 'pending';

const
  BLOCKS_PER_DAY = 5760; // 4 * 60 * 24

const
  ADDRESS_ZERO: TAddress = '0x0000000000000000000000000000000000000000';

function  blockNumber(client: TWeb3): BigInteger; overload;
procedure blockNumber(client: TWeb3; callback: TAsyncQuantity); overload;

procedure getBalance(client: TWeb3; address: TAddress; callback: TAsyncQuantity); overload;
procedure getBalance(client: TWeb3; address: TAddress; const block: string; callback: TAsyncQuantity); overload;

procedure getTransactionCount(client: TWeb3; address: TAddress; callback: TAsyncQuantity); overload;
procedure getTransactionCount(client: TWeb3; address: TAddress; const block: string; callback: TAsyncQuantity); overload;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncString); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncString); overload;
procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString); overload;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity); overload;
procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity); overload;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean); overload;
procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean); overload;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple); overload;
procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple); overload;

function sign(privateKey: TPrivateKey; const msg: string): TSignature;

// transact with a non-payable function.
// default to the median gas price from the latest blocks.
// default to a 200,000 gas limit.
procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt); overload;

// transact with a payable function.
// default to the median gas price from the latest blocks.
// default to a 200,000 gas limit.
procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt); overload;

// transact with a non-payable function.
// default to the median gas price from the latest blocks.
procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  gasLimit  : TWei;
  callback  : TAsyncReceipt); overload;

// transact with a payable function.
// default to the median gas price from the latest blocks.
procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  gasLimit  : TWei;
  callback  : TAsyncReceipt); overload;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  gasPrice  : TWei;
  gasLimit  : TWei;
  callback  : TAsyncReceipt); overload;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : TWei;
  callback  : TAsyncReceipt); overload;

implementation

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  // CryptoLib4Pascal
  ClpBigInteger,
  ClpIECPrivateKeyParameters,
  // Web3
  web3.crypto,
  web3.eth.abi,
  web3.eth.crypto,
  web3.eth.gas,
  web3.eth.tx,
  web3.json,
  web3.json.rpc,
  web3.utils;

function blockNumber(client: TWeb3): BigInteger;
var
  obj: TJsonObject;
begin
  obj := web3.json.rpc.send(client.URL, 'eth_blockNumber', []);
  if Assigned(obj) then
  try
    Result := web3.json.getPropAsStr(obj, 'result');
  finally
    obj.Free;
  end;
end;

procedure blockNumber(client: TWeb3; callback: TAsyncQuantity);
begin
  web3.json.rpc.send(client.URL, 'eth_blockNumber', [], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure getBalance(client: TWeb3; address: TAddress; callback: TAsyncQuantity);
begin
  getBalance(client, address, BLOCK_LATEST, callback);
end;

procedure getBalance(client: TWeb3; address: TAddress; const block: string; callback: TAsyncQuantity);
begin
  web3.json.rpc.send(client.URL, 'eth_getBalance', [address, block], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure getTransactionCount(client: TWeb3; address: TAddress; callback: TAsyncQuantity);
begin
  getTransactionCount(client, address, BLOCK_LATEST, callback);
end;

// returns the number of transations *sent* from an address
procedure getTransactionCount(client: TWeb3; address: TAddress; const block: string; callback: TAsyncQuantity);
begin
  web3.json.rpc.send(client.URL, 'eth_getTransactionCount', [address, block], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(resp, 'result'), nil);
  end);
end;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncString);
begin
  call(client, ADDRESS_ZERO, &to, func, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncString);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString);
begin
  call(client, ADDRESS_ZERO, &to, func, block, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncString);
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
  ));
  try
    // step #3: execute a message call (without creating a transaction on the blockchain)
    web3.json.rpc.send(client.URL, 'eth_call', [obj, block], procedure(resp: TJsonObject; err: IError)
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

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, ADDRESS_ZERO, &to, func, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, ADDRESS_ZERO, &to, func, block, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncQuantity);
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      if (hex = '') or (hex = '0x') then
        callback(0, nil)
      else
        callback(hex, nil);
  end);
end;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, ADDRESS_ZERO, &to, func, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, ADDRESS_ZERO, &to, func, block, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncBoolean);
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: IError)
  var
    buf: TBytes;
  begin
    if Assigned(err) then
      callback(False, err)
    else
    begin
      buf := fromHex(hex);
      callback((Length(buf) > 0) and (buf[High(buf)] <> 0), nil);
    end;
  end);
end;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, ADDRESS_ZERO, &to, func, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple);
begin
  call(client, ADDRESS_ZERO, &to, func, block, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TAsyncTuple);
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
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt);
begin
  write(client, from, &to, 0, func, args, callback);
end;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TAsyncReceipt);
begin
  write(client, from, &to, value, func, args, 200000, callback);
end;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  gasLimit  : TWei;
  callback  : TAsyncReceipt);
begin
  write(client, from, &to, 0, func, args, gasLimit, callback);
end;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  gasLimit  : TWei;
  callback  : TAsyncReceipt);
var
  data: string;
begin
  data := web3.eth.abi.encode(func, args);
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      write(client, from, &to, value, data, gasPrice, gasLimit, callback);
  end);
end;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  gasPrice  : TWei;
  gasLimit  : TWei;
  callback  : TAsyncReceipt);
begin
  write(client, from, &to, value, web3.eth.abi.encode(func, args), gasPrice, gasLimit, callback);
end;

procedure write(
  client    : TWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : TWei;
  callback  : TAsyncReceipt);
begin
  web3.eth.getTransactionCount(
    client,
    from.Address,
    procedure(qty: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, err)
      else
        signTransaction(client, qty, from, &to, value, data, gasPrice, gasLimit,
          procedure(const sig: string; err: IError)
          begin
            if Assigned(err) then
              callback(nil, err)
            else
              sendTransactionEx(client, sig, callback);
          end);
    end
  );
end;

end.
