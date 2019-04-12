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
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.types;

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
  TASyncAddress = reference to procedure(addr: TAddress;    err: Exception);
  TASyncTuple   = reference to procedure(tup : TTuple;      err: Exception);
  TASyncTxHash  = reference to procedure(tx  : TTxHash;     err: Exception);
  TASyncReceipt = reference to procedure(rcpt: TJsonObject; err: Exception);

type
  TAddressHelper = record helper for TAddress
    class function  New(arg: TArg): TAddress; overload; static;
    class function  New(const hex: string): TAddress; overload; static;
    class procedure New(client: TWeb3; const name: string; callback: TASyncAddress); overload; static;
    procedure ToString(client: TWeb3; callback: TASyncString);
  end;

type
  TTupleHelper = record helper for TTuple
    function Add     : PArg;
    function Last    : PArg;
    function ToString: string;
  end;

function toHex(arg: TArg; const prefix: string): string;
function toInt(arg: TArg): UInt64;

implementation

uses
  // web3
  web3.eth.ens,
  web3.utils;

{ TArg }

function toHex(arg: TArg; const prefix: string): string;
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

function ToInt(arg: TArg): UInt64;
begin
  Result := StrToInt64(toHex(arg, '$'));
end;

{ TAddressHelper }

class function TAddressHelper.New(arg: TArg): TAddress;
begin
  Result := New(toHex(arg, '0x'));
end;

class function TAddressHelper.New(const hex: string): TAddress;
var
  buf: TBytes;
begin
  if web3.utils.isHex(hex) and (hex.IndexOf('.') = -1) then
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

class procedure TAddressHelper.New(client: TWeb3; const name: string; callback: TASyncAddress);
begin
  if web3.utils.isHex(name) and (name.IndexOf('.') = -1) then
    callback(New(name), nil)
  else
    web3.eth.ens.addr(client, name, callback);
end;

procedure TAddressHelper.ToString(client: TWeb3; callback: TASyncString);
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
  Arg: TArg;
  Len: Integer;
begin
  Result := '';
  if Length(Self) < 2 then
    EXIT;
  Arg := Self[Length(Self) - 2];
  Len := toInt(Arg);
  if Len = 0 then
    EXIT;
  Arg := Self[Length(Self) - 1];
  Result := TEncoding.UTF8.GetString(Arg);
  SetLength(Result, Len);
end;

end.
