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
  System.Generics.Collections,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3;

type
  TContractArray = TList<Variant>;

function  tuple(args: array of Variant): Variant;

function &array(args: array of Variant): TContractArray; overload;
function &array(args: array of TAddress): TContractArray; overload;
function &array(args: array of BigInteger): TContractArray; overload;

function encode(const func: string; args: array of const): string;

implementation

uses
  // Delphi
  System.SysUtils,
  System.Variants,
  // web3
  web3.utils;

function tuple(args: array of Variant): Variant;
var
  I: Integer;
begin
  Result := VarArrayCreate([0, High(args)], varVariant);
  for I := 0 to High(args) do Result[I] := args[I];
end;

function &array(args: array of Variant): TContractArray;
var
  arg: Variant;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(arg);
end;

function &array(args: array of TAddress): TContractArray;
var
  arg: TAddress;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(arg);
end;

function &array(args: array of BigInteger): TContractArray;
var
  arg: BigInteger;
begin
  Result := TContractArray.Create;
  for arg in args do Result.Add(web3.utils.toHex(arg));
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
        while (hex = '') or (Length(hex) mod 64 <> 0) do hex := hex + '0';
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

    function isDynamic(const arg: Variant): Boolean; overload;
    var
      I: Integer;
    begin
      Result := False;
      case FindVarData(arg)^.VType of
        varOleStr,
        varStrArg,
        varUStrArg,
        varString,
        varUString:
          Result := Copy(string(arg), Low(string(arg)), 2) <> '0x';
      else
        if VarIsArray(arg) then // tuple is dynamic if any of the elements is dynamic
          for I := VarArrayLowBound(arg, 1) to VarArrayHighBound(arg, 1) do
          begin
            Result := isDynamic(VarArrayGet(arg, [I]));
            if Result then
              EXIT;
          end;
      end;
    end;

    function encodeArg(const arg: Variant): TBytes; overload;

      function VarArrayCount(const arg: Variant): Integer;
      var
        I: Integer;
      begin
        Result := 0;
        if VarIsArray(arg) then
        begin
          Result := VarArrayHighBound(arg, 1) - VarArrayLowBound(arg, 1) + 1;
          for I := VarArrayLowBound(arg, 1) to VarArrayHighBound(arg, 1) do
            Result := Result + VarArrayCount(VarArrayGet(arg, [I]));
        end;
      end;

    var
      idx   : Integer;
      elem  : Variant;
      curr  : TBytes;
      suffix: TBytes;
      offset: Integer;
    begin
      Result := [];
      case FindVarData(arg)^.VType of
        varSmallint,
        varShortInt,
        varInteger:
          Result := encodeArg(Integer(arg));
        varByte,
        varWord,
        varUInt32:
          Result := encodeArg(Cardinal(arg));
        varInt64:
          Result := encodeArg(Int64(arg));
        varUInt64:
          Result := encodeArg(UInt64(arg));
        varOleStr,
        varStrArg,
        varUStrArg,
        varString,
        varUString:
          Result := encodeArg(string(arg));
        varBoolean:
          Result := encodeArg(Boolean(arg));
      else
        if VarIsArray(arg) then // tuple
        begin
          offset  := (VarArrayCount(arg) - 1) * 32;
          for idx := VarArrayLowBound(arg, 1) to VarArrayHighBound(arg, 1) do
          begin
            elem := VarArrayGet(arg, [idx]);
            curr := encodeArg(elem);
            if isDynamic(elem) then
            begin
              Result := Result + encodeArg(offset);
              suffix := suffix + curr;
              offset := offset + Length(curr);
            end
            else
              Result := Result + curr;
          end;
          Result := Result + suffix;
        end;
      end;
    end;

    function encodeArg(const arg: TVarRec): TBytes; overload;
    var
      elem  : Variant;
      curr  : TBytes;
      suffix: TBytes;
      offset: Integer;
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
        vtVariant:
          Result := encodeArg(arg.VVariant^);
        vtObject:
          if arg.VObject is TContractArray then // array
          begin
            Result := encodeArg((arg.VObject as TContractArray).Count);
            offset := (arg.VObject as TContractArray).Count * 32;
            for elem in arg.VObject as TContractArray do
            begin
              curr := encodeArg(elem);
              if isDynamic(elem) then
              begin
                Result := Result + encodeArg(offset);
                suffix := suffix + curr;
                offset := offset + Length(curr);
              end
              else
                Result := Result + curr;
            end;
            Result := Result + suffix;
          end;
      end;
    end;

    function isDynamic(const arg: TVarRec): Boolean; overload;
    var
      S: string;
    begin
      Result := False;
      if arg.VType = vtVariant then
        Result := isDynamic(arg.VVariant^)
      else
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
    suffix: TBytes;
    offset: Integer;
  begin
    Result := [];
    offset := Length(args) * 32;
    for arg in args do
    begin
      curr := encodeArg(arg);
      if isDynamic(arg) then
      begin
        Result := Result + encodeArg(offset);
        suffix := suffix + curr;
        offset := offset + Length(curr);
      end
      else
        Result := Result + curr;
    end;
    Result := Result + suffix;
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
