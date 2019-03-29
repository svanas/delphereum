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

unit web3.eth.abi;

{$I web3.inc}

interface

function encode(const func: string; args: array of const): string;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3.utils;

function encode(const func: string; args: array of const): string;

  // https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI#argument-encoding
  function encodeArgs(args: array of const): TBytes;

    function toHex32(const str: string): string;
    var
      buf: TBytes;
    begin
      if Copy(str, Low(str), 2) <> '0x' then
        Result := web3.utils.toHex(str, 32 - Length(str), 32)
      else
      begin
        buf := web3.utils.fromHex(str);
        Result := web3.utils.toHex(buf, 32 - Length(buf), 32);
      end;
    end;

  var
    arg: TVarRec;
  begin
    for arg in args do
    begin
      case arg.VType of
        vtInteger:
          Result := Result + web3.utils.fromHex('0x' + IntToHex(arg.VInteger, 64));
        vtString:
          Result := Result + web3.utils.fromHex(toHex32(UnicodeString(PShortString(arg.VAnsiString)^)));
        vtWideString:
          Result := Result + web3.utils.fromHex(toHex32(WideString(arg.VWideString^)));
        vtInt64:
          Result := Result + web3.utils.fromHex('0x' + IntToHex(arg.VInt64^, 64));
        vtUnicodeString:
          Result := Result + web3.utils.fromHex(toHex32(string(arg.VUnicodeString)));
      end;
    end;
  end;

var
  hash: TBytes;
  data: TBytes;
begin
  // step #1: encode the args into a byte array
  data := encodeArgs(args);
  // step #2: the first four bytes specify the function to be called
  hash := web3.utils.sha3(web3.utils.toHex(func));
  data := Copy(hash, 0, 4) + data;
  // step #3: hex-encode the data
  Result := web3.utils.toHex(data)
end;

end.
