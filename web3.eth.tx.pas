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

procedure getNonce(
  client  : TWeb3;
  address : TAddress;
  callback: TAsyncQuantity);

procedure signTransaction(
  client      : TWeb3;
  nonce       : BigInteger;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  gasPrice    : TWei;
  gasLimit    : TWei;
  estimatedGas: TWei;
  callback    : TAsyncString); overload;

function signTransaction(
  chain     : TChain;
  nonce     : BigInteger;
  from      : TPrivateKey;
  &to       : TAddress;
  value     : TWei;
  const data: string;
  gasPrice  : TWei;
  gasLimit  : TWei): string; overload;

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

var
  gNonce: BigInteger;

procedure getNonce(
  client  : TWeb3;
  address : TAddress;
  callback: TAsyncQuantity);
begin
  if gNonce > -1 then
  begin
    gNonce := BigInteger.Add(gNonce, 1);
    callback(gNonce, nil);
    EXIT;
  end;
  web3.eth.getTransactionCount(client, address, procedure(cnt: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    gNonce := cnt;
    callback(gNonce, nil);
  end);
end;

procedure signTransaction(
  client      : TWeb3;
  nonce       : BigInteger;
  from        : TPrivateKey;
  &to         : TAddress;
  value       : TWei;
  const data  : string;
  gasPrice    : TWei;
  gasLimit    : TWei;
  estimatedGas: TWei;
  callback    : TAsyncString);
resourcestring
  RS_SIGNATURE_DENIED = 'User denied transaction signature';
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      client.CanSignTransaction(addr, &to, gasPrice, estimatedGas, procedure(approved: Boolean; err: IError)
      begin
        if Assigned(err) then
          callback('', err)
        else
          if not approved then
            callback('', TSignatureDenied.Create(RS_SIGNATURE_DENIED))
          else
            callback(signTransaction(client.Chain, nonce, from, &to, value, data, gasPrice, gasLimit), nil);
      end);
  end);
end;

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
          web3.utils.toHex(nonce, [padToEven]),    // nonce
          web3.utils.toHex(gasPrice, [padToEven]), // gasPrice
          web3.utils.toHex(gasLimit, [padToEven]), // gas(Limit)
          &to,                                     // to
          web3.utils.toHex(value, [padToEven]),    // value
          data,                                    // data
          chainId[chain],                          // v
          0,                                       // r
          0                                        // s
        ])
      )
    );

    r := Signature.r;
    s := Signature.s;
    v := Signature.rec.Add(TBigInteger.ValueOf(chainId[chain] * 2 + 35));

    Result :=
      web3.utils.toHex(
        web3.rlp.encode([
          web3.utils.toHex(nonce, [padToEven]),    // nonce
          web3.utils.toHex(gasPrice, [padToEven]), // gasPrice
          web3.utils.toHex(gasLimit, [padToEven]), // gas(Limit)
          &to,                                     // to
          web3.utils.toHex(value, [padToEven]),    // value
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
  web3.json.rpc.send(client.URL, 'eth_sendRawTransaction', [raw], procedure(resp: TJsonObject; err: IError)
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
  sendTransaction(client, raw, procedure(hash: TTxHash; err: IError)
  var
    onReceiptReceived: TAsyncReceipt;
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
      getTransactionRevertReason(client, rcpt, procedure(const reason: string; err: IError)
      begin
        if Assigned(err) then
          callback(rcpt, nil)
        else
          callback(rcpt, TTxError.Create(rcpt.txHash, reason));
      end);
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
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: BigInteger; err: IError)
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
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: BigInteger; err: IError)
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
          signTransaction(client, nonce, from, &to, value, '', gasPrice, gasLimit, 21000,
            procedure(const sig: string; err: IError)
            begin
              if Assigned(err) then
                callback('', err)
              else
                sendTransaction(client, sig, procedure(hash: TTxHash; err: IError)
                begin
                  if Assigned(err) and (err.Message = 'nonce too low') then
                    sendTransaction(client, from, &to, value, gasPrice, gasLimit, callback)
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
procedure sendTransactionEx(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TAsyncReceipt);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.tx.getNonce(client, addr, procedure(nonce: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          signTransaction(
            client, nonce, from, &to, value, '', gasPrice, gasLimit, 21000,
          procedure(const sig: string; err: IError)
          begin
            if Assigned(err) then
              callback(nil, err)
            else
              sendTransactionEx(client, sig, procedure(rcpt: ITxReceipt; err: IError)
              begin
                if Assigned(err) and (err.Message = 'nonce too low') then
                  sendTransactionEx(client, from, &to, value, gasPrice, gasLimit, callback)
                else
                  callback(rcpt, err);
              end);
          end);
      end);
  end);
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
  web3.json.rpc.send(client.URL, 'eth_getTransactionByHash', [hash], procedure(resp: TJsonObject; err: IError)
  begin
    if Assigned(err) then
      callback(nil, TTxError.Create(hash, err.Message))
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
  web3.json.rpc.send(client.URL, 'eth_getTransactionReceipt', [hash], procedure(resp: TJsonObject; err: IError)
  var
    rcpt: TJsonObject;
  begin
    if Assigned(err) then
    begin
      callback(nil, TTxError.Create(hash, err.Message));
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
  TX_DID_NOT_FAIL  = 'Transaction did not fail';
  TX_OUT_OF_GAS    = 'Transaction ran out of gas';
  TX_UNKNOWN_ERROR = 'Unknown error encountered during contract execution';

// get the revert reason for a failed transaction.
procedure getTransactionRevertReason(client: TWeb3; rcpt: ITxReceipt; callback: TAsyncString);
begin
  if rcpt.status then
  begin
    callback(TX_DID_NOT_FAIL, nil);
    EXIT;
  end;

  web3.eth.tx.getTransaction(client, rcpt.txHash, procedure(txn: ITxn; err: IError)
  var
    obj: TJsonObject;
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
        web3.json.quoteString(toHex(txn.value, [zeroAs0x0]), '"'),
        web3.json.quoteString(toHex(txn.gasLimit, [zeroAs0x0]), '"'),
        web3.json.quoteString(toHex(txn.gasPrice, [zeroAs0x0]), '"')
      ]
    ));
    try
      web3.json.rpc.send(client.URL, 'eth_call', [obj, toHex(txn.blockNumber)], procedure(resp: TJsonObject; err: IError)
      var
        len: Int64;
        decoded,
        encoded: string;
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
        if encoded.Length = 0 then
        begin
          callback(TX_UNKNOWN_ERROR, nil);
          EXIT;
        end;
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

initialization
  gNonce := -1;

end.
