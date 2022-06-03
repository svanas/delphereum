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

unit web3.eth.types;

{$I web3.inc}

interface

uses
  // Delphi
  System.Classes,
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
  TBytes32 = array[0..31] of Byte;

type
  TArg = record
    Inner: TBytes32;
  public
    function toAddress: TAddress;
    function toHex(const prefix: string): string;
    function toInt: Integer;
    function toInt64: Int64;
    function toBigInt: BigInteger;
    function toBoolean: Boolean;
    function toString: string;
    function toDateTime: TUnixDateTime;
  end;

type
  PArg    = ^TArg;
  TTuple  = TArray<TArg>;
  TTopics = array[0..3] of TArg;

type
  IBlock = interface
    function ToString: string;
    function baseFeePerGas: TWei;
  end;

  ITxn = interface
    function &type: Byte;
    function ToString: string;
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

type
  ITxReceipt = interface
    function ToString: string;
    function txHash: TTxHash;         // hash of the transaction.
    function from: TAddress;          // address of the sender.
    function &to: TAddress;           // address of the receiver. null when it's a contract creation transaction.
    function gasUsed: BigInteger;     // the amount of gas used by this specific transaction.
    function status: Boolean;         // success or failure.
    function effectiveGasPrice: TWei; // eip-1559-only
  end;

type
  TAsyncString    = reference to procedure(const str: string; err : IError);
  TAsyncQuantity  = reference to procedure(qty  : BigInteger; err : IError);
  TAsyncBoolean   = reference to procedure(bool : Boolean;    err : IError);
  TAsyncAddress   = reference to procedure(addr : TAddress;   err : IError);
  TAsyncBytes32   = reference to procedure(bytes: TBytes32;   err : IError);
  TAsyncArg       = reference to procedure(arg  : TArg;       next: TProc);
  TAsyncTuple     = reference to procedure(tup  : TTuple;     err : IError);
  TAsyncTxHash    = reference to procedure(hash : TTxHash;    err : IError);
  TAsyncBlock     = reference to procedure(block: IBlock;     err : IError);
  TAsyncTxn       = reference to procedure(txn  : ITxn;       err : IError);
  TAsyncReceipt   = reference to procedure(rcpt : ITxReceipt; err : IError);
  TAsyncReceiptEx = reference to procedure(rcpt : ITxReceipt; qty : BigInteger; err: IError);
  TAsyncFloat     = reference to procedure(value: Double;     err : IError);

type
  TAddressHelper = record helper for TAddress
    class function  New(arg: TArg): TAddress; overload; static;
    class function  New(const hex: string): TAddress; overload; static;
    class procedure New(client: IWeb3; const name: string; callback: TAsyncAddress); overload; static;
    procedure ToString(client: IWeb3; callback: TAsyncString; abbreviated: Boolean = False);
    function  Abbreviated: string;
    function  IsZero: Boolean;
    function  SameAs(const other: TAddress): Boolean;
  end;

type
  TPrivateKeyHelper = record helper for TPrivateKey
    class function Generate: TPrivateKey; static;
    class function New(params: IECPrivateKeyParameters): TPrivateKey; static;
    function Parameters: IECPrivateKeyParameters;
    procedure Address(callback: TAsyncAddress);
  end;

type
  TTupleHelper = record helper for TTuple
    function Add: PArg;
    function Last: PArg;
    function Empty: Boolean;
    function Strings: Boolean;
    function ToArray: TArray<TArg>;
    function ToString: string;
    function ToStrings: TStrings;
    class function From(const hex: string): TTuple;
    procedure Enumerate(callback: TAsyncArg; done: TProc);
  end;

implementation

uses
  // web3
  web3.crypto,
  web3.eth,
  web3.eth.ens,
  web3.http,
  web3.utils;

{ TArg }

function TArg.toAddress: TAddress;
begin
  Result := TAddress.New(Self);
end;

function TArg.toHex(const prefix: string): string;
const
  Digits = '0123456789ABCDEF';
begin
  Result := StringOfChar('0', Length(Inner) * 2);
  try
    for var I := 0 to Length(Inner) - 1 do
    begin
      Result[2 * I + 1] := Digits[(Inner[I] shr 4)  + 1];
      Result[2 * I + 2] := Digits[(Inner[I] and $F) + 1];
    end;
  finally
    Result := prefix + Result;
  end;
end;

function TArg.toInt: Integer;
begin
  Result := StrToInt(Self.toHex('$'));
end;

function TArg.toInt64: Int64;
begin
  Result := StrToInt64(Self.toHex('$'));
end;

function TArg.toBigInt: BigInteger;
begin
  Result := Self.toHex('0x');
end;

function TArg.toBoolean: Boolean;
begin
  Result := Self.toInt <> 0;
end;

function TArg.toString: string;
begin
  Result := TEncoding.UTF8.GetString(Inner);
end;

function TArg.toDateTime: TUnixDateTime;
begin
  Result := Self.toInt64;
end;

{ TAddressHelper }

class function TAddressHelper.New(arg: TArg): TAddress;
begin
  Result := New(arg.toHex('0x'));
end;

class function TAddressHelper.New(const hex: string): TAddress;
begin
  if not web3.utils.isHex(hex) then
  begin
    Result := EMPTY_ADDRESS;
    EXIT;
  end;
  var buf := web3.utils.fromHex(hex);
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

class procedure TAddressHelper.New(client: IWeb3; const name: string; callback: TAsyncAddress);
begin
  if web3.utils.isHex(name) then
    callback(New(name), nil)
  else
    web3.eth.ens.addr(client, name, callback);
end;

procedure TAddressHelper.ToString(client: IWeb3; callback: TAsyncString; abbreviated: Boolean);
begin
  const addr: TAddress = Self;
  web3.eth.ens.reverse(client, addr, procedure(const name: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback('', err);
      EXIT;
    end;

    var output := (function: string
    begin
      if  (name <> '')
      and (name.ToLower <> '0x')
      and (name.ToLower <> '0x0000000000000000000000000000000000000000') then
        Result := name
      else
        Result := string(addr);
    end)();

    if abbreviated then
      if isHex(output) then
        output := Copy(output, System.Low(output), 8);

    callback(output, nil);
  end);
end;

function TAddressHelper.Abbreviated: string;
begin
  Result := string(Self);
  Result := Copy(Result, System.Low(Result), 8);
end;

function TAddressHelper.IsZero: Boolean;
begin
  Result := (Self = '')
         or (string(Self).ToLower = '0x')
         or (string(Self).ToLower = '0x0')
         or (string(Self).ToLower = '0x0000000000000000000000000000000000000000');
end;

function TAddressHelper.SameAs(const other: TAddress): Boolean;
begin
  Result := SameText(string(self), string(other));
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

procedure TPrivateKeyHelper.Address(callback: TAsyncAddress);
begin
  try
    const pubKey = web3.crypto.publicKeyFromPrivateKey(Self.Parameters);
    var buffer := web3.utils.sha3(pubKey);
    Delete(buffer, 0, 12);
    callback(TAddress.New(web3.utils.toHex(buffer)), nil);
  except
    callback(EMPTY_ADDRESS, TError.Create('Private key is invalid'));
  end;
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

function TTupleHelper.Empty: Boolean;
begin
  Result := (Length(Self) < 2) or (Self[1].toInt64 = 0);
end;

function TTupleHelper.Strings: Boolean;
begin
  Result := (not Self.Empty) and (Length(Self) > (Self[1].toInt + 2));
end;

function TTupleHelper.ToArray: TArray<TArg>;
begin
  Result := [];
  if Length(Self) < 3 then
    EXIT;
  const len = Self[1].toInt;
  if len = 0 then
    EXIT;
  for var idx := 2 to High(Self) do
    Result := Result + [Self[idx]];
  SetLength(Result, len);
end;

function TTupleHelper.ToString: string;
begin
  Result := '';

  if Self.Empty then
    EXIT;

  if Self.Strings then
  begin
    const SL = Self.ToStrings;
    if Assigned(SL) then
    try
      Result := TrimRight(SL.Text);
    finally
      SL.Free;
    end;
    EXIT;
  end;

  if Length(Self) < 3 then
    EXIT;
  const len = Self[1].toInt;
  if len = 0 then
    EXIT;
  for var idx := 2 to High(Self) do
    Result := Result + Self[idx].toString;
  SetLength(Result, len);
end;

function TTupleHelper.ToStrings: TStrings;
begin
  Result := nil;
  if Length(Self) < 3 then
    EXIT;
  var len := Self[1].toInt;
  if len = 0 then
    EXIT;
  Result := TStringList.Create;
  for var idx := 2 to len + 1 do
  begin
    const ndx = Self[idx].toInt div SizeOf(TArg) + 2;
    len := Self[ndx].toInt;
    var str := Self[ndx + 1].toString;
    SetLength(str, len);
    Result.Add(str);
  end;
end;

class function TTupleHelper.From(const hex: string): TTuple;
begin
  var tup: TTuple;
  var buf: TBytes := web3.utils.fromHex(hex);
  while Length(buf) >= 32 do
  begin
    SetLength(tup, Length(tup) + 1);
    Move(buf[0], tup[High(tup)].Inner[0], 32);
    Delete(buf, 0, 32);
  end;
  Result := tup;
end;

procedure TTupleHelper.Enumerate(callback: TAsyncArg; done: TProc);
begin
  var Next: TProc<Integer, TArray<TArg>>;

  Next := procedure(idx: Integer; arr: TArray<TArg>)
  begin
    if idx >= Length(arr) then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    callback(arr[idx], procedure
    begin
      Next(idx + 1, arr);
    end);
  end;

  if Self.Empty then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  Next(0, Self.ToArray);
end;

end.
