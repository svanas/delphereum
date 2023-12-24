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
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.types;

type
  ITxError = interface(IError)
  ['{52B97571-7EF2-4BA3-929D-4AB5A131D570}']
    function Hash: TTxHash;
  end;

  TTxError = class(TError, ITxError)
  private
    FHash: TTxHash;
  public
    constructor Create(const aHash: TTxHash; const aMsg: string);
    function Hash: TTxHash;
  end;

procedure signTransaction(
  const client      : IWeb3;
  const nonce       : BigInteger;
  const from        : TPrivateKey;
  const &to         : TAddress;
  const value       : TWei;
  const data        : string;
  const gasLimit    : BigInteger;
  const estimatedGas: BigInteger;
  const callback    : TProc<string, IError>);

function signTransactionLegacy(
  const chainId : Integer;
  const nonce   : BigInteger;
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : TWei;
  const data    : string;
  const gasPrice: TWei;
  const gasLimit: BigInteger): IResult<string>;

function signTransactionType2(
  const chainId       : Integer;
  const nonce         : BigInteger;
  const from          : TPrivateKey;
  const &to           : TAddress;
  const value         : TWei;
  const data          : string;
  const maxPriorityFee: TWei;
  const maxFee        : TWei;
  const gasLimit      : BigInteger): IResult<string>;

// recover signer from Ethereum-signed transaction
function ecrecoverTransaction(const encoded: TBytes): IResult<TAddress>;

// send raw (aka signed) transaction.
procedure sendTransaction(
  const client  : IWeb3;
  const raw     : string;
  const callback: TProc<TTxHash, IError>); overload;

// send raw transaction, get the receipt, and get the reason if the transaction failed.
procedure sendTransaction(
  const client  : IWeb3;
  const raw     : string;
  const callback: TProc<ITxReceipt, IError>); overload;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction.
procedure sendTransaction(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : TWei;
  const callback: TProc<TTxHash, IError>); overload;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction, then
// 4. get the transaction receipt, then
// 5. get the reason if the transaction failed.
procedure sendTransaction(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : TWei;
  const callback: TProc<ITxReceipt, IError>); overload;

// returns the information about a transaction requested by transaction hash.
procedure getTransaction(
  const client  : IWeb3;
  const hash    : TTxHash;
  const callback: TProc<ITransaction, IError>);

// returns the receipt of a transaction by transaction hash.
procedure getTransactionReceipt(
  const client  : IWeb3;
  const hash    : TTxHash;
  const callback: TProc<ITxReceipt, IError>);

// get the revert reason for a failed transaction.
procedure getTransactionRevertReason(
  const client  : IWeb3;
  const rcpt    : ITxReceipt;
  const callback: TProc<string, IError>);

// cancel a pending transaction
procedure cancelTransaction(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const nonce   : BigInteger;
  const callback: TProc<TTxHash, IError>);

// open transaction in block explorer
procedure openTransaction(const chain: TChain; const hash: TTxHash);

// create transaction from JSON value
function createTransaction(const value: TJsonValue): ITransaction;

implementation

uses
  // Delphi
  System.Variants,
{$IFDEF MSWINDOWS}
  WinAPI.ShellAPI,
  WinAPI.Windows,
{$ENDIF MSWINDOWS}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF POSIX}
  // CryptoLib4Pascal
  ClpBigInteger,
  // web3
  web3.error,
  web3.eth,
  web3.eth.crypto,
  web3.eth.gas,
  web3.eth.nonce,
  web3.json,
  web3.rlp,
  web3.utils;

{ TTxError }

constructor TTxError.Create(const aHash: TTxHash; const aMsg: string);
begin
  inherited Create(aMsg);
  FHash := aHash;
end;

function TTxError.Hash: TTxHash;
begin
   Result := FHash;
end;

procedure signTransaction(
  const client      : IWeb3;
  const nonce       : BigInteger;
  const from        : TPrivateKey;
  const &to         : TAddress;
  const value       : TWei;
  const data        : string;
  const gasLimit    : BigInteger;
  const estimatedGas: BigInteger;
  const callback    : TProc<string, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback('', err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.gas.getGasPrice(client, procedure(gasPrice: TWei; err: IError)
      begin
        if Assigned(err) then
        begin
          callback('', err);
          EXIT;
        end;
        client.CanSignTransaction(sender, &to, gasPrice, estimatedGas, procedure(approved: Boolean; err: IError)
        begin
          if Assigned(err) then
          begin
            callback('', err);
            EXIT;
          end;

          if not approved then
          begin
            callback('', TSignatureDenied.Create);
            EXIT;
          end;

          if client.Chain.TxType >= 2 then // EIP-1559
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
                signTransactionType2(client.Chain.Id, nonce, from, &to, value, data, tip, max, gasLimit).into(callback);
              end);
            end);
            EXIT;
          end;

          signTransactionLegacy(client.Chain.Id, nonce, from, &to, value, data, gasPrice, gasLimit).into(callback);
        end);
      end);
    end);
end;

function signTransactionLegacy(
  const chainId : Integer;
  const nonce   : BigInteger;
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : TWei;
  const data    : string;
  const gasPrice: TWei;
  const gasLimit: BigInteger): IResult<string>;
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

  if encoded.isErr then
  begin
    Result := TResult<string>.Err('', encoded.Error);
    EXIT;
  end;

  const Signer = TEthereumSigner.Create;
  try
    Signer.Init(True, from);

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

    if encoded.isErr then
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
  const chainId       : Integer;
  const nonce         : BigInteger;
  const from          : TPrivateKey;
  const &to           : TAddress;
  const value         : TWei;
  const data          : string;
  const maxPriorityFee: TWei;
  const maxFee        : TWei;
  const gasLimit      : BigInteger): IResult<string>;
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

  if encoded.isErr then
  begin
    Result := TResult<string>.Err('', encoded.Error);
    EXIT;
  end;

  const Signer = TEthereumSigner.Create;
  try
    Signer.Init(True, from);

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

    if encoded.isErr then
    begin
      Result := TResult<string>.Err('', encoded.Error);
      EXIT;
    end;

    Result := TResult<string>.Ok(web3.utils.toHex([2] + encoded.Value));
  finally
    Signer.Free;
  end;
end;

// recover signer from legacy transaction
function ecrecoverTransactionLegacy(const encoded: TBytes): IResult<TAddress>;

  function getChainId(const V: TBytes): IResult<Int32>;
  begin
    if Length(V) = 0 then
    begin
      Result := TResult<Int32>.Err(0, 'V is null');
      EXIT;
    end;
    var I: Int32 := V[0];
    if Length(V) = 2 then
      I := 256 * I + V[1];
    if I < 35 then
    begin
      Result := TResult<Int32>.Err(0, 'V is out of range');
      EXIT;
    end;
    if I mod 2 = 0 then
      I := I - 36
    else
      I := I - 35;
    Result := TResult<Int32>.Ok(I div 2);
  end;

begin
  const decoded = web3.rlp.decode(encoded);
  if decoded.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, decoded.Error);
    EXIT;
  end;

  if (Length(decoded.Value) <> 1) or (decoded.Value[0].DataType <> dtList) then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, 'not a legacy transaction');
    EXIT;
  end;

  const signature = web3.rlp.decode(decoded.Value[0].Bytes);
  if signature.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, signature.Error);
    EXIT;
  end;

  if Length(signature.Value) < 9 then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, 'not a legacy transaction');
    EXIT;
  end;

  const chainId = getChainId(signature.Value[6].Bytes);
  if chainId.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, signature.Error);
    EXIT;
  end;

  const msg = web3.rlp.recode([
    signature.Value[0],                                          // nonce
    signature.Value[1],                                          // gasPrice
    signature.Value[2],                                          // gas(Limit)
    signature.Value[3],                                          // to
    signature.Value[4],                                          // value
    signature.Value[5],                                          // data
    TItem.Create(fromHex(IntToHex(chainId.Value, 0)), dtString), // v
    TItem.Create([], dtString),                                  // r
    TItem.Create([], dtString)                                   // s
  ]);

  if msg.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, msg.Error);
    EXIT;
  end;

  Result := ecrecover(sha3(msg.Value), TSignature.Create(
    TBigInteger.Create(1, signature.Value[7].Bytes),  // R
    TBigInteger.Create(1, signature.Value[8].Bytes),  // S
    TBigInteger.Create(1, signature.Value[6].Bytes)), // V
    function(const V: TBigInteger): IResult<Int32>
    begin
      const B = V.ToByteArrayUnsigned;
      if Length(B) = 0 then
      begin
        Result := TResult<Int32>.Err(0, 'V is null');
        EXIT;
      end;
      var I: Int32 := B[0];
      if Length(B) = 2 then
        I := 256 * I + B[1];
      if I < 35 then
      begin
        Result := TResult<Int32>.Err(0, 'V is out of range');
        EXIT;
      end;
      if I mod 2 = 0 then
        Result := TResult<Int32>.Ok(1)
      else
        Result := TResult<Int32>.Ok(0);
    end);
end;

// recover signer from EIP-1559 transaction
function ecrecoverTransactionType2(const encoded: TBytes): IResult<TAddress>;
begin
  const decoded = web3.rlp.decode(encoded);
  if decoded.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, decoded.Error);
    EXIT;
  end;

  if (Length(decoded.Value) <> 2)
  or (Length(decoded.Value[0].Bytes) <> 1)
  or (decoded.Value[0].Bytes[0] < 2)
  or (decoded.Value[1].DataType <> dtList) then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, 'not an EIP-1559 transaction');
    EXIT;
  end;

  const signature = web3.rlp.decode(decoded.Value[1].Bytes);
  if signature.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, signature.Error);
    EXIT;
  end;

  if Length(signature.Value) < 12 then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, 'not an EIP-1559 transactionn');
    EXIT;
  end;

  const msg = web3.rlp.recode([
    signature.Value[0], // chainId
    signature.Value[1], // nonce
    signature.Value[2], // maxPriorityFeePerGas
    signature.Value[3], // maxFeePerGas
    signature.Value[4], // gas(Limit)
    signature.Value[5], // to
    signature.Value[6], // value
    signature.Value[7], // data
    signature.Value[8]  // accessList
  ]);

  if msg.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, msg.Error);
    EXIT;
  end;

  Result := ecrecover(sha3([decoded.Value[0].Bytes[0]] + msg.Value), TSignature.Create(
    TBigInteger.Create(1, signature.Value[10].Bytes), // R
    TBigInteger.Create(1, signature.Value[11].Bytes), // S
    TBigInteger.Create(1, signature.Value[9].Bytes)), // V
    function(const V: TBigInteger): IResult<Int32>
    begin
      const bytes = V.ToByteArrayUnsigned;
      if Length(bytes) = 0 then
        Result := TResult<Int32>.Ok(0)
      else
        Result := TResult<Int32>.Ok(bytes[0]);
    end);
end;

// recovery signer from Ethereum-signed transaction
function ecrecoverTransaction(const encoded: TBytes): IResult<TAddress>;
begin
  const decoded = web3.rlp.decode(encoded);
  if decoded.isErr then
  begin
    Result := TResult<TAddress>.Err(TAddress.Zero, decoded.Error);
    EXIT;
  end;

  // EIP-1559 ['2', [signature]]
  if Length(decoded.Value) = 2 then
  begin
    const i0 = decoded.Value[0];
    const i1 = decoded.Value[1];
    if (Length(i0.Bytes) = 1) and (i0.Bytes[0] >= 2) and (i1.DataType = dtList) then
    begin
      Result := ecRecoverTransactionType2(encoded);
      EXIT;
    end;
  end;

  // Legacy transaction
  if (Length(decoded.Value) = 1) and (decoded.Value[0].DataType = dtList) then
  begin
    Result := ecRecoverTransactionLegacy(encoded);
    EXIT;
  end;

  Result := TResult<TAddress>.Err(TAddress.Zero, 'unknown transaction encoding');
end;

// send raw (aka signed) transaction.
procedure sendTransaction(const client: IWeb3; const raw: string; const callback: TProc<TTxHash, IError>);
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
procedure sendTransaction(const client: IWeb3; const raw: string; const callback: TProc<ITxReceipt, IError>);
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
  const client  : IWeb3;
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : TWei;
  const callback: TProc<TTxHash, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback('', err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.nonce.get(client, sender, procedure(nonce: BigInteger; err: IError)
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
    end);
end;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction, then
// 4. get the transaction receipt, then
// 5. get the reason if the transaction failed.
procedure sendTransaction(
  const client  : IWeb3;
  const from    : TPrivateKey;
  const &to     : TAddress;
  const value   : TWei;
  const callback: TProc<ITxReceipt, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.nonce.get(client, sender, procedure(nonce: BigInteger; err: IError)
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
      end)
    end);
end;

{ TTransaction }

type
  TTransaction = class(TDeserialized, ITransaction)
  public
    function &type: Byte;
    function blockNumber: BigInteger;    // block number where this transaction was in. null when its pending.
    function timeStamp: TUnixDateTime;   // the unix timestamp for when the transaction got mined.
    function from: TAddress;             // address of the sender.
    function gasLimit: BigInteger;       // gas limit provided by the sender.
    function gasPrice: TWei;             // gas price provided by the sender in Wei.
    function maxPriorityFeePerGas: TWei; // EIP-1559-only
    function maxFeePerGas: TWei;         // EIP-1559-only
    function input: string;              // the data send along with the transaction.
    function &to: TAddress;              // address of the receiver. null when its a contract creation transaction.
    function value: TWei;                // value transferred in Wei.
  end;

function TTransaction.&type: Byte;
begin
  if (Self.maxPriorityFeePerGas > 0) or (Self.maxFeePerGas > 0) then
    Result := 2 // EIP-1559
  else
    Result := 0; // Legacy
end;

// block number where this transaction was in. null when its pending.
function TTransaction.blockNumber: BigInteger;
begin
  Result := getPropAsStr(FJsonValue, 'blockNumber', '0x0');
end;

// the unix timestamp for when the transaction got mined.
function TTransaction.timeStamp: TUnixDateTime;
begin
  Result := getPropAsBigInt(FJsonValue, 'timeStamp').AsInt64;
end;

// address of the sender.
function TTransaction.from: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from'));
end;

// gas limit provided by the sender.
function TTransaction.gasLimit: BigInteger;
begin
  Result := getPropAsStr(FJsonValue, 'gas', '0x5208');
end;

// gas price provided by the sender in Wei.
function TTransaction.gasPrice: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'gasPrice', '0x0');
end;

// EIP-1559-only
function TTransaction.maxPriorityFeePerGas: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'maxPriorityFeePerGas', '0x0');
end;

// EIP-1559-only
function TTransaction.maxFeePerGas: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'maxFeePerGas', '0x0');
end;

// the data send along with the transaction.
function TTransaction.input: string;
begin
  Result := web3.json.getPropAsStr(FJsonValue, 'input');
end;

// address of the receiver. null when its a contract creation transaction.
function TTransaction.&to: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'to'));
end;

// value transferred in Wei.
function TTransaction.value: TWei;
begin
  Result := getPropAsStr(FJsonValue, 'value', '0x0');
end;

function createTransaction(const value: TJsonValue): ITransaction;
begin
  Result := TTransaction.Create(value);
end;

// returns the information about a transaction requested by transaction hash.
procedure getTransaction(const client: IWeb3; const hash: TTxHash; const callback: TProc<ITransaction, IError>);
begin
  client.Call('eth_getTransactionByHash', [hash], procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, TTxError.Create(hash, err.Message))
    else
      callback(createTransaction(web3.json.getPropAsObj(response, 'result')), nil);
  end);
end;

{ TTxReceipt }

type
  TTxReceipt = class(TDeserialized, ITxReceipt)
  public
    function txHash: TTxHash;         // hash of the transaction.
    function from: TAddress;          // address of the sender.
    function &to: TAddress;           // address of the receiver. null when it's a contract creation transaction.
    function gasUsed: BigInteger;     // the amount of gas used by this specific transaction.
    function status: Boolean;         // success or failure.
    function effectiveGasPrice: TWei; // eip-1559-only
  end;

// hash of the transaction.
function TTxReceipt.txHash: TTxHash;
begin
  Result := TTxHash(getPropAsStr(FJsonValue, 'transactionHash', ''));
end;

// address of the sender.
function TTxReceipt.from: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'from'));
end;

// address of the receiver. null when it's a contract creation transaction.
function TTxReceipt.&to: TAddress;
begin
  Result := TAddress.Create(getPropAsStr(FJsonValue, 'to'));
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
procedure getTransactionReceipt(const client: IWeb3; const hash: TTxHash; const callback: TProc<ITxReceipt, IError>);
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
procedure getTransactionRevertReason(const client: IWeb3; const rcpt: ITxReceipt; const callback: TProc<string, IError>);
begin
  if rcpt.status then
  begin
    callback(TX_SUCCESS, nil);
    EXIT;
  end;

  web3.eth.tx.getTransaction(client, rcpt.txHash, procedure(txn: ITransaction; err: IError)
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
  const client  : IWeb3;
  const from    : TPrivateKey;
  const nonce   : BigInteger;
  const callback: TProc<TTxHash, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback('', err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      signTransaction(client, nonce, from, sender, 0, '', 21000, 21000, procedure(sig: string; err: IError)
      begin
        if Assigned(err) then
          callback('', err)
        else
          sendTransaction(client, sig, callback);
      end);
    end);
end;

procedure openTransaction(const chain: TChain; const hash: TTxHash);

  procedure open(const URL: string); inline;
  begin
  {$IFDEF MSWINDOWS}
    ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
  {$ENDIF MSWINDOWS}
  {$IFDEF POSIX}
    _system(PAnsiChar('open ' + AnsiString(URL)));
  {$ENDIF POSIX}
  end;

begin
  open(chain.Explorer + '/tx/' + string(hash));
end;

end.
