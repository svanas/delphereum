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

unit web3.eth.tx;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  System.Variants,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // CryptoLib4Pascal
  ClpBigInteger,
  // web3
  web3,
  web3.crypto,
  web3.eth,
  web3.eth.crypto,
  web3.eth.gas,
  web3.eth.nonce,
  web3.eth.types,
  web3.eth.utils,
  web3.json,
  web3.json.rpc,
  web3.rlp,
  web3.sync,
  web3.utils;

type
  ITxError = interface(IError)
  ['{52B97571-7EF2-4BA3-929D-4AB5A131D570}']
    function Hash: TTxHash;
  end;

  TTxError = class(TError, ITxError)
  private
    FHash: TTxHash;
  public
    constructor Create(aHash: TTxHash; const aMsg: string);
    function Hash: TTxHash;
  end;

procedure signTransaction(
  client      : IWeb3;
  nonce       : BigInteger;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  gasLimit    : BigInteger;
  estimatedGas: BigInteger;
  callback    : TProc<string, IError>);

function signTransactionLegacy(
  chainId   : Integer;
  nonce     : BigInteger;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : BigInteger): IResult<string>;

function signTransactionType2(
  chainId       : Integer;
  nonce         : BigInteger;
  from          : TPrivateKey;
  &to           : TAddress;
  value         : TWei;
  const data    : string;
  maxPriorityFee: TWei;
  maxFee        : TWei;
  gasLimit      : BigInteger): IResult<string>;

// send raw (aka signed) transaction.
procedure sendTransaction(
  client   : IWeb3;
  const raw: string;
  callback : TProc<TTxHash, IError>); overload;

// send raw transaction, get the receipt, and get the reason if the transaction failed.
procedure sendTransaction(
  client   : IWeb3;
  const raw: string;
  callback : TProc<ITxReceipt, IError>); overload;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction.
procedure sendTransaction(
  client  : IWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TProc<TTxHash, IError>); overload;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction, then
// 4. get the transaction receipt, then
// 5. get the reason if the transaction failed.
procedure sendTransaction(
  client  : IWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TProc<ITxReceipt, IError>); overload;

// returns the information about a transaction requested by transaction hash.
procedure getTransaction(
  client  : IWeb3;
  hash    : TTxHash;
  callback: TProc<ITxn, IError>);

// returns the receipt of a transaction by transaction hash.
procedure getTransactionReceipt(
  client  : IWeb3;
  hash    : TTxHash;
  callback: TProc<ITxReceipt, IError>);

// get the revert reason for a failed transaction.
procedure getTransactionRevertReason(
  client  : IWeb3;
  rcpt    : ITxReceipt;
  callback: TProc<string, IError>);

// cancel a pending transaction
procedure cancelTransaction(
  client  : IWeb3;
  from    : TPrivateKey;
  nonce   : BigInteger;
  callback: TProc<TTxHash, IError>); overload;

implementation

{ TTxError }

constructor TTxError.Create(aHash: TTxHash; const aMsg: string);
begin
  inherited Create(aMsg);
  FHash := aHash;
end;

function TTxError.Hash: TTxHash;
begin
   Result := FHash;
end;

procedure signTransaction(
  client      : IWeb3;
  nonce       : BigInteger;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  gasLimit    : BigInteger;
  estimatedGas: BigInteger;
  callback    : TProc<string, IError>);
resourcestring
  RS_SIGNATURE_DENIED = 'User denied transaction signature';
begin
  const sender = from.GetAddress;
  if sender.IsErr then
  begin
    callback('', sender.Error);
    EXIT;
  end;
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: TWei; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;
    client.CanSignTransaction(sender.Value, &to, gasPrice, estimatedGas, procedure(approved: Boolean; err: IError)
    begin
      if Assigned(err) then
      begin
        callback('', err);
        EXIT;
      end;

      if not approved then
      begin
        callback('', TSignatureDenied.Create(RS_SIGNATURE_DENIED));
        EXIT;
      end;

      if client.TxType >= 2 then // EIP-1559
      begin
        web3.eth.gas.getMaxPriorityFeePerGas(client, procedure(tip: BigInteger; err: IError)
        begin
          if Assigned(err) then
          begin
            callback('', err);
            EXIT;
          end;
          web3.eth.gas.getMaxFeePerGas(client, procedure(max: BigInteger; err: IError)
          begin
            if Assigned(err) then
            begin
              callback('', err);
              EXIT;
            end;
            signTransactionType2(client.Chain.Id, nonce, from, &to, value, data, tip, max, gasLimit).Into(callback);
          end);
        end);
        EXIT;
      end;

      signTransactionLegacy(client.Chain.Id, nonce, from, &to, value, data, gasPrice, gasLimit).Into(callback);
    end);
  end);
end;

function signTransactionLegacy(
  chainId   : Integer;
  nonce     : BigInteger;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : BigInteger): IResult<string>;
begin
  var encoded: IResult<TBytes>;

  encoded := web3.rlp.encode([
    web3.utils.toHex(nonce, [padToEven]),    // nonce
    web3.utils.toHex(gasPrice, [padToEven]), // gasPrice
    web3.utils.toHex(gasLimit, [padToEven]), // gas(Limit)
    &to,                                     // to
    web3.utils.toHex(value, [padToEven]),    // value
    data,                                    // data
    chainId,                                 // v
    0,                                       // r
    0                                        // s
  ]);

  if encoded.IsErr then
  begin
    Result := TResult<string>.Err('', encoded.Error);
    EXIT;
  end;

  const Signer = TEthereumSigner.Create;
  try
    Signer.Init(True, from.Parameters);

    const Signature = Signer.GenerateSignature(sha3(encoded.Value));

    const r = Signature.r;
    const s = Signature.s;
    const v = Signature.rec.Add(TBigInteger.ValueOf(chainId * 2 + 35));

    encoded := web3.rlp.encode([
      web3.utils.toHex(nonce, [padToEven]),    // nonce
      web3.utils.toHex(gasPrice, [padToEven]), // gasPrice
      web3.utils.toHex(gasLimit, [padToEven]), // gas(Limit)
      &to,                                     // to
      web3.utils.toHex(value, [padToEven]),    // value
      data,                                    // data
      web3.utils.toHex(v.ToByteArrayUnsigned), // v
      web3.utils.toHex(r.ToByteArrayUnsigned), // r
      web3.utils.toHex(s.ToByteArrayUnsigned)  // s
    ]);

    if encoded.IsErr then
    begin
      Result := TResult<string>.Err('', encoded.Error);
      EXIT;
    end;

    Result := TResult<string>.Ok(web3.utils.toHex(encoded.Value));
  finally
    Signer.Free;
  end;
end;

function signTransactionType2(
  chainId       : Integer;
  nonce         : BigInteger;
  from          : TPrivateKey;
  &to           : TAddress;
  value         : TWei;
  const data    : string;
  maxPriorityFee: TWei;
  maxFee        : TWei;
  gasLimit      : BigInteger): IResult<string>;
begin
  var encoded: IResult<TBytes>;

  encoded := web3.rlp.encode([
    web3.utils.toHex(chainId),                     // chainId
    web3.utils.toHex(nonce, [padToEven]),          // nonce
    web3.utils.toHex(maxPriorityFee, [padToEven]), // maxPriorityFeePerGas
    web3.utils.toHex(maxFee, [padToEven]),         // maxFeePerGas
    web3.utils.toHex(gasLimit, [padToEven]),       // gas(Limit)
    &to,                                           // to
    web3.utils.toHex(value, [padToEven]),          // value
    data,                                          // data
    VarArrayCreate([0, 0], varVariant)             // accessList
  ]);

  if encoded.IsErr then
  begin
    Result := TResult<string>.Err('', encoded.Error);
    EXIT;
  end;

  const Signer = TEthereumSigner.Create;
  try
    Signer.Init(True, from.Parameters);

    const Signature = Signer.GenerateSignature(sha3([2] + encoded.Value));

    const r = Signature.r;
    const s = Signature.s;
    const v = Signature.rec;

    encoded := web3.rlp.encode([
      web3.utils.toHex(chainId),                     // chainId
      web3.utils.toHex(nonce, [padToEven]),          // nonce
      web3.utils.toHex(maxPriorityFee, [padToEven]), // maxPriorityFeePerGas
      web3.utils.toHex(maxFee, [padToEven]),         // maxFeePerGas
      web3.utils.toHex(gasLimit, [padToEven]),       // gas(Limit)
      &to,                                           // to
      web3.utils.toHex(value, [padToEven]),          // value
      data,                                          // data
      VarArrayCreate([0, 0], varVariant),            // accessList
      web3.utils.toHex(v.ToByteArrayUnsigned),       // v
      web3.utils.toHex(r.ToByteArrayUnsigned),       // r
      web3.utils.toHex(s.ToByteArrayUnsigned)        // s
    ]);

    if encoded.IsErr then
    begin
      Result := TResult<string>.Err('', encoded.Error);
      EXIT;
    end;

    Result := TResult<string>.Ok(web3.utils.toHex([2] + encoded.Value));
  finally
    Signer.Free;
  end;
end;

// send raw (aka signed) transaction.
procedure sendTransaction(client: IWeb3; const raw: string; callback: TProc<TTxHash, IError>);
begin
  client.Call('eth_sendRawTransaction', [raw], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TTxHash(web3.json.getPropAsStr(response, 'result')), nil);
  end);
end;

// send raw transaction, get the receipt, and get the reason if the transaction failed.
procedure sendTransaction(client: IWeb3; const raw: string; callback: TProc<ITxReceipt, IError>);
var
  onReceiptReceived: TProc<ITxReceipt, IError>;
begin
  // send the raw transaction
  sendTransaction(client, raw, procedure(hash: TTxHash; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // get the transaction receipt
    onReceiptReceived := procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(nil, TTxError.Create(hash, err.Message));
        EXIT;
      end;
      // has the transaction been mined, or is it still pending?
      if not Assigned(rcpt) then
      begin
        getTransactionReceipt(client, hash, onReceiptReceived);
        EXIT;
      end;
      // did the transaction fail? then get the reason why it failed
      if rcpt.status then
      begin
        callback(rcpt, nil);
        EXIT;
      end;
      getTransactionRevertReason(client, rcpt, procedure(reason: string; err: IError)
      begin
        if Assigned(err) then
          callback(rcpt, TTxError.Create(hash, err.Message))
        else
          callback(rcpt, TTxError.Create(rcpt.txHash, reason));
      end);
    end;
    getTransactionReceipt(client, hash, onReceiptReceived);
  end);
end;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction.
procedure sendTransaction(
  client  : IWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TProc<TTxHash, IError>);
begin
  const sender = from.GetAddress;
  if sender.IsErr then
    callback('', sender.Error)
  else
    web3.eth.nonce.get(client, sender.Value, procedure(nonce: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback('', err)
      else
        signTransaction(client, nonce, from, &to, value, '', 21000, 21000, procedure(sig: string; err: IError)
        begin
          if Assigned(err) then
            callback('', err)
          else
            sendTransaction(client, sig, procedure(hash: TTxHash; err: IError)
            begin
              if Assigned(err) and (err.Message = 'nonce too low') then
                sendTransaction(client, from, &to, value, callback)
              else
                callback(hash, err);
            end);
        end);
    end);
end;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction, then
// 4. get the transaction receipt, then
// 5. get the reason if the transaction failed.
procedure sendTransaction(
  client  : IWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TProc<ITxReceipt, IError>);
begin
  const sender = from.GetAddress;
  if sender.IsErr then
    callback(nil, sender.Error)
  else
    web3.eth.nonce.get(client, sender.Value, procedure(nonce: BigInteger; err: IError)
    begin
      if Assigned(err) then
        callback(nil, err)
      else
        signTransaction(client, nonce, from, &to, value, '', 21000, 21000, procedure(sig: string; err: IError)
        begin
          if Assigned(err) then
            callback(nil, err)
          else
            sendTransaction(client, sig, procedure(rcpt: ITxReceipt; err: IError)
            begin
              if Assigned(err) and (err.Message = 'nonce too low') then
                sendTransaction(client, from, &to, value, callback)
              else
                callback(rcpt, err);
            end);
        end);
    end);
end;

{ TTxn }

type
  TTxn = class(TDeserialized<TJsonObject>, ITxn)
  public
    function &type: Byte;
    function ToString: string; override;
    function blockNumber: BigInteger;    // block number where this transaction was in. null when its pending.
    function from: TAddress;             // address of the sender.
    function gasLimit: BigInteger;       // gas limit provided by the sender.
    function gasPrice: TWei;             // gas price provided by the sender in Wei.
    function maxPriorityFeePerGas: TWei; // EIP-1559-only
    function maxFeePerGas: TWei;         // EIP-1559-only
    function input: string;              // the data send along with the transaction.
    function &to: TAddress;              // address of the receiver. null when its a contract creation transaction.
    function value: TWei;                // value transferred in Wei.
  end;

function TTxn.&type: Byte;
begin
  if (Self.maxPriorityFeePerGas > 0) or (Self.maxFeePerGas > 0) then
    Result := 2 // EIP-1559
  else
    Result := 0; // Legacy
end;

function TTxn.ToString: string;
begin
  Result := web3.json.marshal(FJsonValue);
end;

// block number where this transaction was in. null when its pending.
function TTxn.blockNumber: BigInteger;
begin
  Result := getPropAsStr(FJsonValue, 'blockNumber', '0x0');
end;

// address of the sender.
function TTxn.from: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'from'));
end;

// gas limit provided by the sender.
function TTxn.gasLimit: BigInteger;
begin
  Result := getPropAsStr(FJsonValue, 'gas', '0x5208');
end;

// gas price provided by the sender in Wei.
function TTxn.gasPrice: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'gasPrice', '0x0');
end;

// EIP-1559-only
function TTxn.maxPriorityFeePerGas: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'maxPriorityFeePerGas', '0x0');
end;

// EIP-1559-only
function TTxn.maxFeePerGas: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'maxFeePerGas', '0x0');
end;

// the data send along with the transaction.
function TTxn.input: string;
begin
  Result := web3.json.getPropAsStr(FJsonValue, 'input');
end;

// address of the receiver. null when its a contract creation transaction.
function TTxn.&to: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'to'));
end;

// value transferred in Wei.
function TTxn.value: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'value', '0x0');
end;

// returns the information about a transaction requested by transaction hash.
procedure getTransaction(client: IWeb3; hash: TTxHash; callback: TProc<ITxn, IError>);
begin
  client.Call('eth_getTransactionByHash', [hash], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, TTxError.Create(hash, err.Message))
    else
      callback(TTxn.Create(web3.json.getPropAsObj(response, 'result')), nil);
  end);
end;

{ TTxReceipt }

type
  TTxReceipt = class(TDeserialized<TJsonObject>, ITxReceipt)
  public
    function ToString: string; override;
    function txHash: TTxHash;         // hash of the transaction.
    function from: TAddress;          // address of the sender.
    function &to: TAddress;           // address of the receiver. null when it's a contract creation transaction.
    function gasUsed: BigInteger;     // the amount of gas used by this specific transaction.
    function status: Boolean;         // success or failure.
    function effectiveGasPrice: TWei; // eip-1559-only
  end;

function TTxReceipt.ToString: string;
begin
  Result := web3.json.marshal(FJsonValue);
end;

// hash of the transaction.
function TTxReceipt.txHash: TTxHash;
begin
  Result := TTxHash(getPropAsStr(FJsonValue, 'transactionHash', ''));
end;

// address of the sender.
function TTxReceipt.from: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'from'));
end;

// address of the receiver. null when it's a contract creation transaction.
function TTxReceipt.&to: TAddress;
begin
  Result := TAddress.New(getPropAsStr(FJsonValue, 'to'));
end;

// the amount of gas used by this specific transaction.
function TTxReceipt.gasUsed: BigInteger;
begin
  Result := getPropAsStr(FJsonValue, 'gasUsed', '0x0');
end;

// success or failure.
function TTxReceipt.status: Boolean;
begin
  Result := getPropAsStr(FJsonValue, 'status', '0x1') = '0x1';
end;

// eip-1559-ony
function TTxReceipt.effectiveGasPrice: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'effectiveGasPrice', '0x0');
end;

// returns the receipt of a transaction by transaction hash.
procedure getTransactionReceipt(client: IWeb3; hash: TTxHash; callback: TProc<ITxReceipt, IError>);
begin
  client.Call('eth_getTransactionReceipt', [hash], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(nil, TTxError.Create(hash, err.Message));
      EXIT;
    end;
    const receipt = web3.json.getPropAsObj(response, 'result');
    if Assigned(receipt) then
      callback(TTxReceipt.Create(receipt), nil)
    else
      callback(nil, nil); // transaction is pending
  end);
end;

resourcestring
  TX_SUCCESS       = 'Success';
  TX_OUT_OF_GAS    = 'Out of gas';
  TX_UNKNOWN_ERROR = 'Unknown error encountered during contract execution';

// get the revert reason for a failed transaction.
procedure getTransactionRevertReason(client: IWeb3; rcpt: ITxReceipt; callback: TProc<string, IError>);
begin
  if rcpt.status then
  begin
    callback(TX_SUCCESS, nil);
    EXIT;
  end;

  web3.eth.tx.getTransaction(client, rcpt.txHash, procedure(txn: ITxn; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;

    if rcpt.gasUsed = txn.gasLimit then
    begin
      callback(TX_OUT_OF_GAS, nil);
      EXIT;
    end;

    if rcpt.gasUsed.AsInt64 / txn.gasLimit.AsInt64 > 0.98 then
    begin
      callback(TX_OUT_OF_GAS, nil);
      EXIT;
    end;

    const obj = (function: TJsonObject
    begin
      // eth_call the failed transaction *with the block number from the receipt*
      if txn.&type >= 2 then
        Result := web3.json.unmarshal(Format(
          '{"to": %s, "data": %s, "from": %s, "value": %s, "gas": %s, "maxPriorityFeePerGas": %s, "maxFeePerGas": %s}', [
            web3.json.quoteString(string(txn.&to), '"'),
            web3.json.quoteString(txn.input, '"'),
            web3.json.quoteString(string(txn.from), '"'),
            web3.json.quoteString(toHex(txn.value, [zeroAs0x0]), '"'),
            web3.json.quoteString(toHex(txn.gasLimit, [zeroAs0x0]), '"'),
            web3.json.quoteString(toHex(txn.maxPriorityFeePerGas, [zeroAs0x0]), '"'),
            web3.json.quoteString(toHex(txn.maxFeePerGas, [zeroAs0x0]), '"')
          ]
        )) as TJsonObject
      else
        Result := web3.json.unmarshal(Format(
          '{"to": %s, "data": %s, "from": %s, "value": %s, "gas": %s, "gasPrice": %s}', [
            web3.json.quoteString(string(txn.&to), '"'),
            web3.json.quoteString(txn.input, '"'),
            web3.json.quoteString(string(txn.from), '"'),
            web3.json.quoteString(toHex(txn.value, [zeroAs0x0]), '"'),
            web3.json.quoteString(toHex(txn.gasLimit, [zeroAs0x0]), '"'),
            web3.json.quoteString(toHex(txn.gasPrice, [zeroAs0x0]), '"')
          ]
        )) as TJsonObject;
    end)();

    if Assigned(obj) then
    try
      client.Call('eth_call', [obj, toHex(txn.blockNumber)], procedure(response: TJsonObject; err: IError)
      begin
        if Assigned(err) then
        begin
          callback('', err);
          EXIT;
        end;

        // parse the reason from the response
        var encoded := web3.json.getPropAsStr(response, 'result');
        // trim the 0x prefix
        Delete(encoded, System.Low(encoded), 2);
        if encoded.Length = 0 then
        begin
          callback(TX_UNKNOWN_ERROR, nil);
          EXIT;
        end;
        // get the length of the revert reason
        const len = StrToInt64('$' + Copy(encoded, System.Low(encoded) + 8 + 64, 64));
        // using the length and known offset, extract the revert reason
        encoded := Copy(encoded, System.Low(encoded) + 8 + 128, len * 2);
        // convert reason from hex to string
        const decoded = TEncoding.UTF8.GetString(fromHex(encoded));

        callback(decoded, nil);
      end);
    finally
      obj.Free;
    end;
  end);
end;

procedure cancelTransaction(
  client  : IWeb3;
  from    : TPrivateKey;
  nonce   : BigInteger;
  callback: TProc<TTxHash, IError>);
begin
  const sender = from.GetAddress;
  if sender.IsErr then
    callback('', sender.Error)
  else
    signTransaction(client, nonce, from, sender.Value, 0, '', 21000, 21000, procedure(sig: string; err: IError)
    begin
      if Assigned(err) then
        callback('', err)
      else
        sendTransaction(client, sig, callback);
    end);
end;

end.
