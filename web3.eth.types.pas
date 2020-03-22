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

unit web3.eth.types;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.Net.HttpClient,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // CryptoLib4Pascal
  ClpIECPrivateKeyParameters,
  // web3
  web3;

type
  TAddress    = string[42];
  TPrivateKey = string[64];
  TArg        = array[0..31] of Byte;
  PArg        = ^TArg;
  TTuple      = TArray<TArg>;
  TSignature  = string[132];
  TWei        = BigInteger;
  TTxHash     = string[66];
  TTopics     = array[0..3] of TArg;

type
  ITxn = interface
    function ToString: string;
    function blockNumber: BigInteger; // block number where this transaction was in. null when its pending.
    function from: TAddress;          // address of the sender.
    function gasLimit: TWei;          // gas provided by the sender.
    function gasPrice: TWei;          // gas price provided by the sender in Wei.
    function input: string;           // the data send along with the transaction.
    function &to: TAddress;           // address of the receiver. null when its a contract creation transaction.
    function value: TWei;             // value transferred in Wei.
  end;

type
  ITxReceipt = interface
    function ToString: string;
    function txHash: TTxHash; // hash of the transaction.
    function from: TAddress;  // address of the sender.
    function &to: TAddress;   // address of the receiver. null when it's a contract creation transaction.
    function gasUsed: TWei;   // the amount of gas used by this specific transaction.
    function status: Boolean; // success or failure.
  end;

type
  TAsyncString     = reference to procedure(const str: string;   err: Exception);
  TAsyncQuantity   = reference to procedure(qty : BigInteger;    err: Exception);
  TAsyncBoolean    = reference to procedure(bool: Boolean;       err: Exception);
  TAsyncResponse   = reference to procedure(resp: IHttpResponse; err: Exception);
  TAsyncJsonObject = reference to procedure(obj : TJsonObject;   err: Exception);
  TAsyncAddress    = reference to procedure(addr: TAddress;      err: Exception);
  TAsyncTuple      = reference to procedure(tup : TTuple;        err: Exception);
  TAsyncTxHash     = reference to procedure(hash: TTxHash;       err: Exception);
  TAsyncTxn        = reference to procedure(txn : ITxn;          err: Exception);
  TAsyncReceipt    = reference to procedure(rcpt: ITxReceipt;    err: Exception);

type
  TAddressHelper = record helper for TAddress
    class function  New(arg: TArg): TAddress; overload; static;
    class function  New(const hex: string): TAddress; overload; static;
    class procedure New(client: TWeb3; const name: string; callback: TAsyncAddress); overload; static;
    procedure ToString(client: TWeb3; callback: TAsyncString);
  end;

type
  TPrivateKeyHelper = record helper for TPrivateKey
    class function Generate: TPrivateKey; static;
    class function New(params: IECPrivateKeyParameters): TPrivateKey; static;
    function Parameters: IECPrivateKeyParameters;
    function Address: TAddress;
  end;

type
  TTupleHelper = record helper for TTuple
    function Add     : PArg;
    function Last    : PArg;
    function ToString: string;
  end;

function toHex(const prefix: string; arg: TArg): string;
function toInt(arg: TArg): UInt64;
function toBool(arg: TArg): Boolean;

implementation

uses
  // web3
  web3.crypto,
  web3.eth.ens,
  web3.utils;

{ TArg }

function toHex(const prefix: string; arg: TArg): string;
const
  Digits = '0123456789ABCDEF';
var
  I: Integer;
begin
  Result := StringOfChar('0', Length(Arg) * 2);
  try
    for I := 0 to Length(arg) - 1 do
    begin
      Result[2 * I + 1] := Digits[(arg[I] shr 4)  + 1];
      Result[2 * I + 2] := Digits[(arg[I] and $F) + 1];
    end;
  finally
    Result := prefix + Result;
  end;
end;

function toInt(arg: TArg): UInt64;
begin
  Result := StrToInt64(toHex('$', arg));
end;

function toBool(arg: TArg): Boolean;
begin
  Result := toInt(arg) <> 0;
end;

{ TAddressHelper }

class function TAddressHelper.New(arg: TArg): TAddress;
begin
  Result := New(toHex('0x', arg));
end;

class function TAddressHelper.New(const hex: string): TAddress;
var
  buf: TBytes;
begin
  if web3.utils.isHex(hex) then
    // we're good
  else
    raise EWeb3.CreateFmt('%s is not a valid address.', [hex]);
  buf := web3.utils.fromHex(hex);
  if Length(buf) = 20 then
    Result := TAddress(hex)
  else
    if Length(buf) < 20 then
    begin
      repeat
        buf := [0] + buf;
      until Length(buf) = 20;
      Result := TAddress(web3.utils.toHex(buf));
    end
    else
      Result := TAddress(web3.utils.toHex(Copy(buf, Length(buf) - 20, 20)));
end;

class procedure TAddressHelper.New(client: TWeb3; const name: string; callback: TAsyncAddress);
begin
  if web3.utils.isHex(name) then
    callback(New(name), nil)
  else
    web3.eth.ens.addr(client, name, callback);
end;

procedure TAddressHelper.ToString(client: TWeb3; callback: TAsyncString);
var
  addr: TAddress;
begin
  addr := Self;
  web3.eth.ens.reverse(client, addr, procedure(const name: string; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
      if (name <> '') and (name <> '0x') then
        callback(name, nil)
      else
        callback(string(addr), nil);
  end);
end;

{ TPrivateKeyHelper }

class function TPrivateKeyHelper.Generate: TPrivateKey;
begin
  Result := New(web3.crypto.generatePrivateKey('ECDSA', SECP256K1));
end;

class function TPrivateKeyHelper.New(params: IECPrivateKeyParameters): TPrivateKey;
begin
  Result := TPrivateKey(web3.utils.toHex('', params.D.ToByteArrayUnsigned));
end;

function TPrivateKeyHelper.Parameters: IECPrivateKeyParameters;
begin
  Result := web3.crypto.privateKeyFromByteArray('ECDSA', SECP256K1, fromHex(string(Self)));
end;

function TPrivateKeyHelper.Address: TAddress;
var
  pubKey: TBytes;
  buffer: TBytes;
begin
  pubKey := web3.crypto.publicKeyFromPrivateKey(Self.Parameters);
  buffer := web3.utils.sha3(pubKey);
  Delete(buffer, 0, 12);
  Result := TAddress(web3.utils.toHex(buffer));
end;

{ TTupleHelper }

function TTupleHelper.Add: PArg;
begin
  SetLength(Self, Length(Self) + 1);
  Result := Last;
end;

function TTupleHelper.Last: PArg;
begin
  Result := nil;
  if Length(Self) > 0 then
    Result := @Self[High(Self)];
end;

function TTupleHelper.ToString: string;
var
  arg: TArg;
  len: Integer;
  idx: Integer;
begin
  Result := '';
  if Length(Self) < 3 then
    EXIT;
  arg := Self[1];
  len := toInt(arg);
  if len = 0 then
    EXIT;
  for idx := 2 to High(Self) do
    Result := Result + TEncoding.UTF8.GetString(Self[idx]);
  SetLength(Result, len);
end;

end.
