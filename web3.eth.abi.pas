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

uses
  // Delphi
  System.Generics.Collections;

type
  TContractArray = TList<Variant>;

function &array(args: array of Variant): TContractArray;
function encode(const func: string; args: array of const): string;

implementation

uses
  // Delphi
  System.SysUtils,
  System.Variants,
  // web3
  web3.utils;

function &array(args: array of Variant): TContractArray;
var
  arg: Variant;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(arg);
end;

function encode(const func: string; args: array of const): string;

  // https://github.com/ethereum/wiki/wiki/Ethereum-Contract-ABI#argument-encoding
  function encodeArgs(args: array of const): TBytes;

    function encodeArg(bool: Boolean): TBytes; overload;
    begin
      Result := web3.utils.fromHex('0x' + IntToHex(Ord(bool), 64));
    end;

    function encodeArg(int: Integer): TBytes; overload;
    begin
      Result := web3.utils.fromHex('0x' + IntToHex(int, 64));
    end;

    function encodeArg(int: Int64): TBytes; overload;
    begin
      Result := web3.utils.fromHex('0x' + IntToHex(int, 64));
    end;

    function encodeArg(const str: string): TBytes; overload;
    var
      buf: TBytes;
      hex: string;
    begin
      if Copy(str, Low(str), 2) <> '0x' then
      begin
        buf := TEncoding.UTF8.GetBytes(str);
        hex := web3.utils.toHex('', buf);
        while Length(hex) mod 64 <> 0 do hex := hex + '0';
        hex := '0x' + IntToHex(Length(buf), 64) + hex;
      end
      else
      begin
        buf := web3.utils.fromHex(str);
        if Length(buf) = 32 then
          hex := str
        else
          hex := web3.utils.toHex(buf, 32 - Length(buf), 32);
      end;
      Result := web3.utils.fromHex(hex);
    end;

    function encodeArg(arg: TVarRec): TBytes; overload;
    var
      V: Variant;
    begin
      case arg.VType of
        vtBoolean:
          Result := encodeArg(arg.VBoolean);
        vtInteger:
          Result := encodeArg(arg.VInteger);
        vtString:
          Result := encodeArg(UnicodeString(PShortString(arg.VAnsiString)^));
        vtWideString:
          Result := encodeArg(WideString(arg.VWideString^));
        vtInt64:
          Result := encodeArg(arg.VInt64^);
        vtUnicodeString:
          Result := encodeArg(string(arg.VUnicodeString));
        vtObject:
          if arg.VObject is TContractArray then
          begin
            Result := encodeArg((arg.VObject as TContractArray).Count);
            for V in arg.VObject as TContractArray do
              case VarType(V) and varTypeMask of
                varSmallint,
                varShortInt,
                varInteger:
                  Result := Result + encodeArg(Integer(V));
                varByte,
                varWord,
                varUInt32:
                  Result := Result + encodeArg(Cardinal(V));
                varInt64:
                  Result := Result + encodeArg(Int64(V));
                varUInt64:
                  Result := Result + encodeArg(UInt64(V));
                varOleStr,
                varStrArg,
                varUStrArg,
                varString,
                varUString:
                  Result := Result + encodeArg(string(V));
                varBoolean:
                  Result := Result + encodeArg(Boolean(V));
              end;
          end;
      end;
    end;

    function isDynamic(arg: TVarRec): Boolean;
    var
      S: string;
    begin
      Result := False;
      if arg.VType = vtObject then
        Result := arg.VObject is TContractArray
      else
        if arg.VType in [vtString, vtWideString, vtUnicodeString] then
        begin
          case arg.VType of
            vtString:
              S := UnicodeString(PShortString(arg.VAnsiString)^);
            vtWideString:
              S := WideString(arg.VWideString^);
            vtUnicodeString:
              S := string(arg.VUnicodeString);
          end;
          Result := Copy(S, Low(S), 2) <> '0x';
        end;
    end;

  var
    arg   : TVarRec;
    curr  : TBytes;
    data  : TBytes;
    offset: Integer;
  begin
    offset := Length(args) * 32;
    for arg in args do
    begin
      curr := encodeArg(arg);
      if isDynamic(arg) then
      begin
        Result := Result + encodeArg(offset);
        data   := data + curr;
        offset := offset + Length(curr);
      end
      else
        Result := Result + curr;
    end;
    Result := Result + data;
  end;

var
  hash: TBytes;
  data: TBytes;
  arg : TVarRec;
begin
  // step #1: encode the args into a byte array
  try
    data := encodeArgs(args);
  finally
    for arg in args do
      if (arg.VType = vtObject) and (arg.VObject is TContractArray) then
        arg.VObject.Free;
  end;
  // step #2: the first four bytes specify the function to be called
  hash := web3.utils.sha3(web3.utils.toHex(func));
  data := Copy(hash, 0, 4) + data;
  // step #3: hex-encode the data
  Result := web3.utils.toHex(data);
end;

end.
