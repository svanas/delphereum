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

function encode(items: array of const): TBytes;

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

function encode(items: array of const): TBytes;
var
  item: TVarRec;
begin
  Result := [];
  if Length(items) = 1 then
    Result := encodeItem(web3.utils.fromHex(web3.utils.toHex(items[0])))
  else
  begin
    for item in items do
      Result := Result + encodeItem(web3.utils.fromHex(web3.utils.toHex(item)));
    Result := encodeLength(Length(Result), $c0) + Result;
  end;
end;

end.
