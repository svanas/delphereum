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

unit web3.eth.tx;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
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
  web3.eth.types,
  web3.eth.utils,
  web3.json,
  web3.json.rpc,
  web3.rlp,
  web3.utils;

function signTransaction(
  chain     : TChain;
  nonce     : BigInteger;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : TWei): string;

// send raw (aka signed) transaction.
procedure sendTransaction(
  client   : TWeb3;
  const raw: string;
  callback : TAsyncTxHash); overload;

// send raw transaction, get the receipt, and get the reason if the transaction failed.
procedure sendTransactionEx(
  client   : TWeb3;
  const raw: string;
  callback : TAsyncReceipt); overload;

// 1. calculate the current gas price, then
// 2. calculate the nonce, then
// 3. sign the transaction, then
// 4. send the raw transaction.
procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TAsyncTxHash); overload;

// 1. calculate the nonce, then
// 2. calculate the current gas price, then
// 3. sign the transaction, then
// 4. send the raw transaction, then
// 5. get the transaction receipt, then
// 6. get the reason if the transaction failed.
procedure sendTransactionEx(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TAsyncReceipt); overload;

// calculate the nonce, then sign the transaction, then send the transaction.
procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TAsyncTxHash); overload;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction, then
// 4. get the transaction receipt, then
// 5. get the reason if the transaction failed.
procedure sendTransactionEx(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TAsyncReceipt); overload;

// returns the information about a transaction requested by transaction hash.
procedure getTransaction(
  client  : TWeb3;
  hash    : TTxHash;
  callback: TAsyncTxn);

// returns the receipt of a transaction by transaction hash.
procedure getTransactionReceipt(
  client  : TWeb3;
  hash    : TTxHash;
  callback: TAsyncReceipt);

// get the revert reason for a failed transaction.
procedure getTransactionRevertReason(
  client  : TWeb3;
  rcpt    : ITxReceipt;
  callback: TAsyncString);

implementation

function signTransaction(
  chain     : TChain;
  nonce     : BigInteger;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : TWei): string;
var
  Signer   : TEthereumSigner;
  Signature: TECDsaSignature;
  r, s, v  : TBigInteger;
begin
  Signer := TEthereumSigner.Create;
  try
    Signer.Init(True, from.Parameters);

    Signature := Signer.GenerateSignature(
      sha3(
        web3.rlp.encode([
          web3.utils.toHex(nonce, True),    // nonce
          web3.utils.toHex(gasPrice, True), // gasPrice
          web3.utils.toHex(gasLimit, True), // gas(Limit)
          &to,                              // to
          web3.utils.toHex(value, True),    // value
          data,                             // data
          chainId[chain],                   // v
          0,                                // r
          0                                 // s
        ])
      )
    );

    r := Signature.r;
    s := Signature.s;
    v := Signature.rec.Add(TBigInteger.ValueOf(chainId[chain] * 2 + 35));

    Result :=
      web3.utils.toHex(
        web3.rlp.encode([
          web3.utils.toHex(nonce, True),           // nonce
          web3.utils.toHex(gasPrice, True),        // gasPrice
          web3.utils.toHex(gasLimit, True),        // gas(Limit)
          &to,                                     // to
          web3.utils.toHex(value, True),           // value
          data,                                    // data
          web3.utils.toHex(v.ToByteArrayUnsigned), // v
          web3.utils.toHex(r.ToByteArrayUnsigned), // r
          web3.utils.toHex(s.ToByteArrayUnsigned)  // s
        ])
      );
  finally
    Signer.Free;
  end;
end;

// send raw (aka signed) transaction.
procedure sendTransaction(client: TWeb3; const raw: string; callback: TAsyncTxHash);
begin
  web3.json.rpc.send(client.URL, 'eth_sendRawTransaction', [raw], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TTxHash(web3.json.getPropAsStr(resp, 'result')), nil);
  end);
end;

// send raw transaction, get the receipt, and get the reason if the transaction failed.
procedure sendTransactionEx(client: TWeb3; const raw: string; callback: TAsyncReceipt);
begin
  // send the raw transaction
  sendTransaction(client, raw, procedure(hash: TTxHash; err: Exception)
  var
    onReceiptReceived: TAsyncReceipt;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    // get the transaction receipt
    onReceiptReceived := procedure(rcpt: ITxReceipt; err: Exception)
    begin
      if Assigned(err) then
      begin
        callback(nil, err);
        EXIT;
      end;
      // has the transaction been mined, or is it still pending?
      if not Assigned(rcpt) then
      begin
        getTransactionReceipt(client, hash, onReceiptReceived);
        EXIT;
      end;
      // did the transaction fail? then get the reason why it failed
      if not rcpt.status then
        getTransactionRevertReason(client, rcpt, procedure(const reason: string; err: Exception)
        begin
          if not Assigned(err) then
            callback(rcpt, EWeb3.Create(reason));
          EXIT;
        end);
      callback(rcpt, nil);
    end;
    getTransactionReceipt(client, hash, onReceiptReceived);
  end);
end;

// 1. calculate the current gas price, then
// 2. calculate the nonce, then
// 3. sign the transaction, then
// 4. send the raw transaction.
procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TAsyncTxHash);
begin
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: BigInteger; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      sendTransaction(client, from, &to, value, gasPrice, 21000, callback);
  end);
end;

// 1. calculate the nonce, then
// 2. calculate the current gas price, then
// 3. sign the transaction, then
// 4. send the raw transaction, then
// 5. get the transaction receipt, then
// 6. get the reason if the transaction failed.
procedure sendTransactionEx(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TAsyncReceipt);
begin
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: BigInteger; err: Exception)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      sendTransactionEx(client, from, &to, value, gasPrice, 21000, callback);
  end);
end;

// calculate the nonce, then sign the transaction, then send the transaction.
procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TAsyncTxHash);
begin
  web3.eth.getTransactionCount(
    client,
    from.Address,
    procedure(qty: BigInteger; err: Exception)
    begin
      if Assigned(err) then
        callback('', err)
      else
        sendTransaction(client, signTransaction(client.Chain, qty, from, &to, value, '', gasPrice, gasLimit), callback);
    end
  );
end;

// 1. calculate the nonce, then
// 2. sign the transaction, then
// 3. send the raw transaction, then
// 4. get the transaction receipt, then
// 5. get the reason if the transaction failed.
procedure sendTransactionEx(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TAsyncReceipt);
begin
  web3.eth.getTransactionCount(
    client,
    from.Address,
    procedure(qty: BigInteger; err: Exception)
    begin
      if Assigned(err) then
        callback(nil, err)
      else
        sendTransactionEx(client, signTransaction(client.Chain, qty, from, &to, value, '', gasPrice, gasLimit), callback);
    end
  );
end;

{ TTxn }

type
  TTxn = class(TInterfacedObject, ITxn)
  private
    FJsonObject: TJsonObject;
  public
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
    function ToString: string; override;
    function blockNumber: BigInteger; // block number where this transaction was in. null when its pending.
    function from: TAddress;          // address of the sender.
    function gasLimit: TWei;          // gas provided by the sender.
    function gasPrice: TWei;          // gas price provided by the sender in Wei.
    function input: string;           // the data send along with the transaction.
    function &to: TAddress;           // address of the receiver. null when its a contract creation transaction.
    function value: TWei;             // value transferred in Wei.
  end;

constructor TTxn.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject.Clone as TJsonObject;
end;

destructor TTxn.Destroy;
begin
  if Assigned(FJsonObject) then FJsonObject.Free;
  inherited Destroy;
end;

function TTxn.ToString: string;
begin
  Result := web3.json.marshal(FJsonObject);
end;

// block number where this transaction was in. null when its pending.
function TTxn.blockNumber: BigInteger;
begin
  Result := getPropAsStr(FJsonObject, 'blockNumber', '0x0');
end;

// address of the sender.
function TTxn.from: TAddress;
begin
  Result := TAddress(getPropAsStr(FJsonObject, 'from', string(ADDRESS_ZERO)));
end;

// gas provided by the sender.
function TTxn.gasLimit: TWei;
begin
  Result := getPropAsStr(FJsonObject, 'gas', '0x5208');
end;

// gas price provided by the sender in Wei.
function TTxn.gasPrice: TWei;
begin
  Result := getPropAsStr(FJsonObject, 'gasPrice', '0x0');
end;

// the data send along with the transaction.
function TTxn.input: string;
begin
  Result := web3.json.getPropAsStr(FJsonObject, 'input');
end;

// address of the receiver. null when its a contract creation transaction.
function TTxn.&to: TAddress;
begin
  Result := TAddress(getPropAsStr(FJsonObject, 'to', string(ADDRESS_ZERO)));
end;

// value transferred in Wei.
function TTxn.value: TWei;
begin
  Result := getPropAsStr(FJsonObject, 'value', '0x0');
end;

// returns the information about a transaction requested by transaction hash.
procedure getTransaction(client: TWeb3; hash: TTxHash; callback: TAsyncTxn);
begin
  web3.json.rpc.send(client.URL, 'eth_getTransactionByHash', [hash], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TTxn.Create(web3.json.getPropAsObj(resp, 'result')), nil);
  end);
end;

{ TTxReceipt }

type
  TTxReceipt = class(TInterfacedObject, ITxReceipt)
  private
    FJsonObject: TJsonObject;
  public
    constructor Create(aJsonObject: TJsonObject);
    destructor Destroy; override;
    function ToString: string; override;
    function txHash: TTxHash; // hash of the transaction.
    function from: TAddress;  // address of the sender.
    function &to: TAddress;   // address of the receiver. null when it's a contract creation transaction.
    function gasUsed: TWei;   // the amount of gas used by this specific transaction.
    function status: Boolean; // success or failure.
  end;

constructor TTxReceipt.Create(aJsonObject: TJsonObject);
begin
  inherited Create;
  FJsonObject := aJsonObject.Clone as TJsonObject;
end;

destructor TTxReceipt.Destroy;
begin
  if Assigned(FJsonObject) then FJsonObject.Free;
  inherited Destroy;
end;

function TTxReceipt.ToString: string;
begin
  Result := web3.json.marshal(FJsonObject);
end;

// hash of the transaction.
function TTxReceipt.txHash: TTxHash;
begin
  Result := TTxHash(getPropAsStr(FJsonObject, 'transactionHash', ''));
end;

// address of the sender.
function TTxReceipt.from: TAddress;
begin
  Result := TAddress(getPropAsStr(FJsonObject, 'from', string(ADDRESS_ZERO)));
end;

// address of the receiver. null when it's a contract creation transaction.
function TTxReceipt.&to: TAddress;
begin
  Result := TAddress(getPropAsStr(FJsonObject, 'to', string(ADDRESS_ZERO)));
end;

// the amount of gas used by this specific transaction.
function TTxReceipt.gasUsed: TWei;
begin
  Result := getPropAsStr(FJsonObject, 'gasUsed', '0x0');
end;

// success or failure.
function TTxReceipt.status: Boolean;
begin
  Result := getPropAsStr(FJsonObject, 'status', '0x1') = '0x1';
end;

// returns the receipt of a transaction by transaction hash.
procedure getTransactionReceipt(client: TWeb3; hash: TTxHash; callback: TAsyncReceipt);
begin
  web3.json.rpc.send(client.URL, 'eth_getTransactionReceipt', [hash], procedure(resp: TJsonObject; err: Exception)
  var
    rcpt: TJsonObject;
  begin
    if Assigned(err) then
    begin
      callback(nil, err);
      EXIT;
    end;
    rcpt := web3.json.getPropAsObj(resp, 'result');
    if Assigned(rcpt) then
      callback(TTxReceipt.Create(rcpt), nil)
    else
      callback(nil, nil); // transaction is pending
  end);
end;

resourcestring
  TX_DID_NOT_FAIL = 'Transaction did not fail';
  TX_OUT_OF_GAS   = 'Transaction ran out of gas';

// get the revert reason for a failed transaction.
procedure getTransactionRevertReason(client: TWeb3; rcpt: ITxReceipt; callback: TAsyncString);
var
  decoded,
  encoded: string;
  len: Int64;
  obj: TJsonObject;
begin
  if rcpt.status then
  begin
    callback(TX_DID_NOT_FAIL, nil);
    EXIT;
  end;

  web3.eth.tx.getTransaction(client, rcpt.txHash, procedure(txn: ITxn; err: Exception)
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

    // eth_call the failed transaction *with the block number from the receipt*
    obj := web3.json.unmarshal(Format(
      '{"to": %s, "data": %s, "from": %s, "value": %s, "gas": %s, "gasPrice": %s}', [
        web3.json.quoteString(string(txn.&to), '"'),
        web3.json.quoteString(txn.input, '"'),
        web3.json.quoteString(string(txn.from), '"'),
        web3.json.quoteString(toHex(txn.value), '"'),
        web3.json.quoteString(toHex(txn.gasLimit), '"'),
        web3.json.quoteString(toHex(txn.gasPrice), '"')
      ]
    ));
    try
      web3.json.rpc.send(client.URL, 'eth_call', [obj, toHex(txn.blockNumber)], procedure(resp: TJsonObject; err: Exception)
      begin
        if Assigned(err) then
        begin
          callback('', err);
          EXIT;
        end;

        // parse the reason from the response
        encoded := web3.json.getPropAsStr(resp, 'result');
        // trim the 0x prefix
        Delete(encoded, Low(encoded), 2);
        // get the length of the revert reason
        len := StrToInt64('$' + Copy(encoded, Low(encoded) + 8 + 64, 64));
        // using the length and known offset, extract the revert reason
        encoded := Copy(encoded, Low(encoded) + 8 + 128, len * 2);
        // convert reason from hex to string
        decoded := TEncoding.UTF8.GetString(fromHex(encoded));

        callback(decoded, nil);
      end);
    finally
      obj.Free;
    end;
  end);
end;

end.
