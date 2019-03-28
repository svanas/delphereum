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
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  TAddress    = string[42];
  TPrivateKey = string[64];
  TArg        = array[0..31] of Byte;
  TTuple      = TArray<TArg>;
  TSignature  = string[132];
  TWei        = BigInteger;
  TTxHash     = string[66];

type
  TASyncTuple  = reference to procedure(tup: TTuple; err: Exception);
  TASyncTxHash = reference to procedure(tx: TTxHash; err: Exception);

type
  TTupleHelper = record helper for TTuple
    function ToString: string;
  end;

implementation

{ TTupleHelper }

function TTupleHelper.ToString: string;

  function toHex(const arg: TArg): string;
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
      Result := '$' + Result;
    end;
  end;

var
  Arg: TArg;
  Len: Integer;
begin
  Result := '';
  if Length(Self) < 2 then
    EXIT;
  Arg := Self[Length(Self) - 2];
  Len := StrToInt(toHex(Arg));
  if Len = 0 then
    EXIT;
  Arg := Self[Length(Self) - 1];
  Result := TEncoding.UTF8.GetString(Arg);
  SetLength(Result, Len);
end;

end.
