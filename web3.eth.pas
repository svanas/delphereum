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
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

const
  // To remember the differences between the block tags you can think of them in the order of oldest to newest block numbers: earliest < finalized < safe < latest < pending
  BLOCK_EARLIEST  = 'earliest';  // The lowest numbered block the client has available. Intuitively, you can think of this as the first block created.
  BLOCK_FINALIZED = 'finalized'; // The most recent crypto-economically secure block, that has been accepted by >2/3 of validators. Typically finalized in two epochs. Cannot be re-orged outside of manual intervention driven by community coordination. Intuitively, this block is very unlikely to be re-orged.
  BLOCK_SAFE      = 'safe';      // The most recent crypto-economically secure block, cannot be re-orged outside of manual intervention driven by community coordination. Intuitively, this block is “unlikely” to be re-orged.
  BLOCK_LATEST    = 'latest';    // The most recent block in the canonical chain observed by the client, this block may be re-orged out of the canonical chain even under healthy/normal conditions. Intuitively, this block is the most recent block observed by the client.
  BLOCK_PENDING   = 'pending';   // A sample next block built by the client on top of latest and containing the set of transactions usually taken from local mempool. Intuitively, you can think of these as blocks that have not been mined yet.
  // safe and finalized are new blog tags introduced after The Merge that define commitment levels for block finality. Unlike latest which increments one block at a time (ex 101, 102, 103), safe and finalized increment every "epoch" (32 blocks), which is every ~6 minutes assuming an average ~12 second block times.

const
  BLOCKS_PER_DAY = 5760; // 4 * 60 * 24

const
  EMPTY_ADDRESS: TAddress = '0x0000000000000000000000000000000000000000';
  EMPTY_BYTES32: TBytes32 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

function  blockNumber(client: IWeb3): IResult<BigInteger>; overload;                 // blocking
procedure blockNumber(client: IWeb3; callback: TProc<BigInteger, IError>); overload; // async

procedure getBlockByNumber(client: IWeb3; callback: TProc<IBlock, IError>); overload;
procedure getBlockByNumber(client: IWeb3; const block: string; callback: TProc<IBlock, IError>); overload;

procedure getBalance(client: IWeb3; address: TAddress; callback: TProc<BigInteger, IError>); overload;
procedure getBalance(client: IWeb3; address: TAddress; const block: string; callback: TProc<BigInteger, IError>); overload;

procedure getTransactionCount(client: IWeb3; address: TAddress; callback: TProc<BigInteger, IError>); overload;
procedure getTransactionCount(client: IWeb3; address: TAddress; const block: string; callback: TProc<BigInteger, IError>); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<string, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<string, IError>); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<string, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<string, IError>); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<BigInteger, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<BigInteger, IError>); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<BigInteger, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<BigInteger, IError>); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<Boolean, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<Boolean, IError>); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<Boolean, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<Boolean, IError>); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<TBytes32, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<TBytes32, IError>); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<TBytes32, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<TBytes32, IError>); overload;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<TTuple, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<TTuple, IError>); overload;
procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<TTuple, IError>); overload;
procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<TTuple, IError>); overload;

function  sign(privateKey: TPrivateKey; const msg: string): TSignature; overload;
procedure sign(client: IWeb3; from: TPrivateKey; &to: TAddress; value: TWei; const data: string; estimatedGas: BigInteger; callback: TProc<string, IError>); overload;

// transact with a non-payable function.
// default to the median gas price from the latest blocks.
// gas limit is twice the estimated gas.
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TProc<TTxHash, IError>); overload;
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TProc<ITxReceipt, IError>); overload;

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
  callback  : TProc<TTxHash, IError>); overload;
procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TProc<ITxReceipt, IError>); overload;

procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TProc<TTxHash, IError>); overload;
procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TProc<ITxReceipt, IError>); overload;

implementation

uses
  // Delphi
  System.JSON,
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

function blockNumber(client: IWeb3): IResult<BigInteger>;
begin
  const response = client.Call('eth_blockNumber', []);
  if Assigned(response.Value) then
  try
    Result := TResult<BigInteger>.Ok(web3.json.getPropAsStr(response.Value, 'result'));
    EXIT;
  finally
    Response.Value.Free;
  end;
  Result := TResult<BigInteger>.Err(0, response.Error);
end;

procedure blockNumber(client: IWeb3; callback: TProc<BigInteger, IError>);
begin
  client.Call('eth_blockNumber', [], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(response, 'result'), nil);
  end);
end;

type
  TBlock = class(TDeserialized<TJsonObject>, IBlock)
  public
    function ToString: string; override;
    function baseFeePerGas: TWei;
  end;

function TBlock.ToString: string;
begin
  Result := web3.json.marshal(FJsonValue);
end;

function TBlock.baseFeePerGas: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'baseFeePerGas', '0x0');
end;

procedure getBlockByNumber(client: IWeb3; callback: TProc<IBlock, IError>);
begin
  getBlockByNumber(client, BLOCK_PENDING, callback);
end;

procedure getBlockByNumber(client: IWeb3; const block: string; callback: TProc<IBlock, IError>);
begin
  client.Call('eth_getBlockByNumber', [block, False], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TBlock.Create(web3.json.getPropAsObj(response, 'result')), nil);
  end);
end;

procedure getBalance(client: IWeb3; address: TAddress; callback: TProc<BigInteger, IError>);
begin
  getBalance(client, address, BLOCK_LATEST, callback);
end;

procedure getBalance(client: IWeb3; address: TAddress; const block: string; callback: TProc<BigInteger, IError>);
begin
  client.Call('eth_getBalance', [address, block], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(response, 'result'), nil);
  end);
end;

procedure getTransactionCount(client: IWeb3; address: TAddress; callback: TProc<BigInteger, IError>);
begin
  getTransactionCount(client, address, BLOCK_LATEST, callback);
end;

// returns the number of transations *sent* from an address
procedure getTransactionCount(client: IWeb3; address: TAddress; const block: string; callback: TProc<BigInteger, IError>);
begin
  client.Call('eth_getTransactionCount', [address, block], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.getPropAsStr(response, 'result'), nil);
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<string, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<string, IError>);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<string, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<string, IError>);
begin
  // step #1: encode the function abi
  const abi = web3.eth.abi.encode(func, args);
  // step #2: construct the transaction call object
  const obj = web3.json.unmarshal(Format(
    '{"from": %s, "to": %s, "data": %s}', [
      web3.json.quoteString(string(from), '"'),
      web3.json.quoteString(string(&to), '"'),
      web3.json.quoteString(abi, '"')
    ]
  )) as TJsonObject;
  try
    // step #3: execute a message call (without creating a transaction on the blockchain)
    client.Call('eth_call', [obj, block], procedure(response: TJsonObject; err: IError)
    begin
      if Assigned(err) then
        callback('', err)
      else
        callback(web3.json.getPropAsStr(response, 'result'), nil);
    end);
  finally
    obj.Free;
  end;
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<BigInteger, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<BigInteger, IError>);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<BigInteger, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<BigInteger, IError>);
begin
  call(client, from, &to, func, block, args, procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      if (hex = '') or (hex.ToLower = '0x') then
        callback(0, nil)
      else
      begin
        const buf = web3.utils.fromHex(hex);
        if Length(buf) <= 32 then
          callback(hex, nil)
        else
          callback(web3.utils.toHex(Copy(buf, 0, 32)), nil);
      end;
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<Boolean, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<Boolean, IError>);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<Boolean, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<Boolean, IError>);
begin
  call(client, from, &to, func, block, args, procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(False, err)
    else
    begin
      const buf = web3.utils.fromHex(hex);
      callback((Length(buf) > 0) and (buf[High(buf)] <> 0), nil);
    end;
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<TBytes32, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<TBytes32, IError>);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<TBytes32, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<TBytes32, IError>);
begin
  call(client, from, &to, func, block, args, procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(EMPTY_BYTES32, err);
      EXIT;
    end;
    const buffer = web3.utils.fromHex(hex);
    if Length(buffer) < 32 then
    begin
      callback(EMPTY_BYTES32, nil);
      EXIT;
    end;
    var result: TBytes32;
    Move(buffer[0], result[0], 32);
    callback(result, nil);
  end);
end;

procedure call(client: IWeb3; &to: TAddress; const func: string; args: array of const; callback: TProc<TTuple, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TProc<TTuple, IError>);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: IWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TProc<TTuple, IError>);
begin
  call(client, EMPTY_ADDRESS, &to, func, block, args, callback);
end;

procedure call(client: IWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TProc<TTuple, IError>);
begin
  call(client, from, &to, func, block, args, procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback([], err)
    else
      callback(TTuple.From(hex), nil);
  end);
end;

function sign(privateKey: TPrivateKey; const msg: string): TSignature;
begin
  const Signer = TEthereumSigner.Create;
  try
    Signer.Init(True, privateKey.Parameters);
    const Signature = Signer.GenerateSignature(
      sha3(
        TEncoding.UTF8.GetBytes(
          #25 + 'Ethereum Signed Message:' + #10 + IntToStr(Length(msg)) + msg
        )
      )
    );
    const v = Signature.rec.Add(TBigInteger.ValueOf(27));
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
  callback  : TProc<TTxHash, IError>);
begin
  write(client, from, &to, 0, func, args, callback);
end;

procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  const func: string;
  args      : array of const;
  callback  : TProc<ITxReceipt, IError>);
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
  callback  : TProc<TTxHash, IError>);
begin
  const sender = from.GetAddress;
  if sender.IsErr then
  begin
    callback('', sender.Error);
    EXIT;
  end;
  const data = web3.eth.abi.encode(func, args);
  web3.eth.gas.estimateGas(client, sender.Value, &to, data, procedure(estimatedGas: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      write(client, from, &to, value, data, estimatedGas, callback);
  end);
end;

procedure write(
  client    : IWeb3;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const func: string;
  args      : array of const;
  callback  : TProc<ITxReceipt, IError>);
begin
  const sender = from.GetAddress;
  if sender.IsErr then
  begin
    callback(nil, sender.Error);
    EXIT;
  end;
  const data = web3.eth.abi.encode(func, args);
  web3.eth.gas.estimateGas(client, sender.Value, &to, data, procedure(estimatedGas: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      write(client, from, &to, value, data, estimatedGas, callback);
  end);
end;

procedure sign(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TProc<string, IError>);
begin
  const sender = from.GetAddress;
  if sender.IsErr then
    callback('', sender.Error)
  else
    web3.eth.tx.getNonce(client, sender.Value, procedure(nonce: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback('', err)
      else
        signTransaction(client, nonce, from, &to, value, data, 2 * estimatedGas, estimatedGas, callback);
    end);
end;

procedure write(
  client      : IWeb3;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  estimatedGas: BigInteger;
  callback    : TProc<TTxHash, IError>);
begin
  sign(client, from, &to, value, data, estimatedGas, procedure(sig: string; err: IError)
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
  callback    : TProc<ITxReceipt, IError>);
begin
  sign(client, from, &to, value, data, estimatedGas, procedure(sig: string; err: IError)
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
