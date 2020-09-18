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
  TArg = record
    Bytes: array[0..31] of Byte;
    function toHex(const prefix: string): string;
    function toInt64: Int64;
    function toBigInt: BigInteger;
    function toBool: Boolean;
    function toString: string;
  end;

type
  PArg    = ^TArg;
  TTuple  = TArray<TArg>;
  TTopics = array[0..3] of TArg;

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
  TAsyncString     = reference to procedure(const str: string;   err: IError);
  TAsyncQuantity   = reference to procedure(qty : BigInteger;    err: IError);
  TAsyncBoolean    = reference to procedure(bool: Boolean;       err: IError);
  TAsyncAddress    = reference to procedure(addr: TAddress;      err: IError);
  TAsyncTuple      = reference to procedure(tup : TTuple;        err: IError);
  TAsyncTxHash     = reference to procedure(hash: TTxHash;       err: IError);
  TAsyncTxn        = reference to procedure(txn : ITxn;          err: IError);
  TAsyncReceipt    = reference to procedure(rcpt: ITxReceipt;    err: IError);
  TAsyncReceiptEx  = reference to procedure(rcpt: ITxReceipt;
                                            qty : BigInteger;    err: IError);
  TAsyncFloat      = reference to procedure(val : Extended;      err: IError);

type
  TAddressHelper = record helper for TAddress
    class function  New(arg: TArg): TAddress; overload; static;
    class function  New(const hex: string): TAddress; overload; static;
    class procedure New(client: TWeb3; const name: string; callback: TAsyncAddress); overload; static;
    procedure ToString(client: TWeb3; callback: TAsyncString; abbreviated: Boolean = False);
    function  IsZero: Boolean;
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
    class function From(const hex: string): TTuple;
  end;

implementation

uses
  // web3
  web3.crypto,
  web3.eth.ens,
  web3.http,
  web3.utils;

{ TArg }

function TArg.toHex(const prefix: string): string;
const
  Digits = '0123456789ABCDEF';
var
  I: Integer;
begin
  Result := StringOfChar('0', Length(Bytes) * 2);
  try
    for I := 0 to Length(Bytes) - 1 do
    begin
      Result[2 * I + 1] := Digits[(Bytes[I] shr 4)  + 1];
      Result[2 * I + 2] := Digits[(Bytes[I] and $F) + 1];
    end;
  finally
    Result := prefix + Result;
  end;
end;

function TArg.toInt64: Int64;
begin
  Result := StrToInt64(Self.toHex('$'));
end;

function TArg.toBigInt: BigInteger;
begin
  Result := Self.toHex('0x');
end;

function TArg.toBool: Boolean;
begin
  Result := Self.toInt64 <> 0;
end;

function TArg.toString: string;
begin
  Result := TEncoding.UTF8.GetString(Bytes);
end;

{ TAddressHelper }

class function TAddressHelper.New(arg: TArg): TAddress;
begin
  Result := New(arg.toHex('0x'));
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

procedure TAddressHelper.ToString(client: TWeb3; callback: TAsyncString; abbreviated: Boolean);
var
  addr: TAddress;
begin
  addr := Self;
  web3.eth.ens.reverse(client, addr, procedure(const name: string; err: IError)
  var
    output: string;
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;

    if  (name <> '')
    and (name <> '0x')
    and (name <> '0x0000000000000000000000000000000000000000') then
      output := name
    else
      output := string(addr);

    if abbreviated then
      if isHex(output) then
        while Length(output) > 8 do
          Delete(output, High(output), 1);

    callback(output, nil);
  end);
end;

function TAddressHelper.IsZero: Boolean;
begin
  Result := (Self = '')
         or (Self = '0x')
         or (Self = '0x0000000000000000000000000000000000000000');
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
  len := arg.toInt64;
  if len = 0 then
    EXIT;
  for idx := 2 to High(Self) do
    Result := Result + Self[idx].toString;
  SetLength(Result, len);
end;

class function TTupleHelper.From(const hex: string): TTuple;
var
  buf: TBytes;
  tup: TTuple;
begin
  buf := web3.utils.fromHex(hex);
  while Length(buf) >= 32 do
  begin
    SetLength(tup, Length(tup) + 1);
    Move(buf[0], tup[High(tup)].Bytes[0], 32);
    Delete(buf, 0, 32);
  end;
  Result := tup;
end;

end.
