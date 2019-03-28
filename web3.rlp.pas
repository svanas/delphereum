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

unit web3.rlp;

{$I web3.inc}

interface

uses
  // Delphi
  System.Math,
  System.SysUtils,
  // Web3
  web3,
  web3.utils;

function encode(item: Integer): TBytes; overload;
function encode(const item: string): TBytes; overload;
function encode(item: TVarRec): TBytes; overload;
function encode(items: array of const): TBytes; overload;

implementation

function encodeLength(len, offset: Integer): TBytes;

  function toBinary(x: Integer): TBytes;
  var
    i, r: Word;
  begin
    if x = 0 then
      Result := []
    else
    begin
      DivMod(x, 256, i, r);
      Result := toBinary(i) + [r];
    end;
  end;

var
  bin: TBytes;
begin
  if len < 56 then
    Result := [len + offset]
  else
    if len < Power(256, 8) then
    begin
      bin := toBinary(len);
      Result := [Length(bin) + offset + 55] + bin;
    end
    else
      raise EWeb3.Create('RLP input is too long.');
end;

function encodeItem(const item: TBytes): TBytes;
var
  len: Integer;
begin
  len := Length(item);
  if (len = 1) and (item[0] < $80) then
    Result := item
  else
    Result := encodeLength(len, $80) + item;
end;

function encode(item: Integer): TBytes;
var
  arg: TVarRec;
begin
  arg.VType := vtInteger;
  arg.VInteger := item;
  Result := encode(arg);
end;

function encode(const item: string): TBytes;
var
  arg: TVarRec;
begin
  arg.VType := vtUnicodeString;
  arg.VUnicodeString := Pointer(item);
  Result := encode(arg);
end;

function encode(item: TVarRec): TBytes;
begin
  Result := encodeItem(web3.utils.fromHex(web3.utils.toHex(item)));
end;

function encode(items: array of const): TBytes;
var
  item: TVarRec;
begin
  Result := [];
  for item in items do
    Result := Result + encode(item);
  Result := encodeLength(Length(Result), $c0) + Result;
end;

end.
