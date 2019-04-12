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

procedure sendTransaction(
  client   : TWeb3;
  const raw: string;
  callback : TASyncTxHash); overload;

procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TASyncTxHash); overload;

procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TASyncTxHash); overload;

procedure getTransactionReceipt(
  client  : TWeb3;
  tx      : TTxHash;
  callback: TASyncReceipt);

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
    Signer.Init(True, web3.eth.crypto.PrivateKeyFromHex(from));

    Signature := Signer.GenerateSignature(
      sha3(
        web3.rlp.encode([
          web3.utils.toHex(nonce),    // nonce
          web3.utils.toHex(gasPrice), // gasPrice
          web3.utils.toHex(gasLimit), // gas(Limit)
          &to,                        // to
          web3.utils.toHex(value),    // value
          data,                       // data
          chainId[chain],             // v
          0,                          // r
          0                           // s
        ])
      )
    );

    r := Signature.r;
    s := Signature.s;
    v := Signature.rec.Add(TBigInteger.ValueOf(chainId[chain] * 2 + 35));

    Result :=
      web3.utils.toHex(
        web3.rlp.encode([
          web3.utils.toHex(nonce),                 // nonce
          web3.utils.toHex(gasPrice),              // gasPrice
          web3.utils.toHex(gasLimit),              // gas(Limit)
          &to,                                     // to
          web3.utils.toHex(value),                 // value
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

procedure sendTransaction(client: TWeb3; const raw: string; callback: TASyncTxHash);
begin
  web3.json.rpc.send(client.URL, 'eth_sendRawTransaction', [raw], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(TTxHash(web3.json.GetPropAsStr(resp, 'result')), nil);
  end);
end;

procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  callback: TASyncTxHash);
begin
  web3.eth.gas.getGasPrice(client, procedure(gasPrice: BigInteger; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      sendTransaction(client, from, &to, value, gasPrice, 21000, callback);
  end);
end;

procedure sendTransaction(
  client  : TWeb3;
  from    : TPrivateKey;
  &to     : TAddress;
  value   : TWei;
  gasPrice: TWei;
  gasLimit: TWei;
  callback: TASyncTxHash);
begin
  web3.eth.getTransactionCount(
    client,
    web3.eth.crypto.AddressFromPrivateKey(web3.eth.crypto.PrivateKeyFromHex(from)),
    procedure(qty: BigInteger; err: Exception)
    begin
      if Assigned(err) then
        callback('', err)
      else
        sendTransaction(client, signTransaction(client.Chain, qty, from, &to, value, '', gasPrice, gasLimit), callback);
    end
  );
end;

procedure getTransactionReceipt(client: TWeb3; tx: TTxHash; callback: TASyncReceipt);
begin
  web3.json.rpc.send(client.URL, 'eth_getTransactionReceipt', [tx], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(web3.json.GetPropAsObj(resp, 'result'), nil);
  end);
end;

end.
