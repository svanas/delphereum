unit web3.eth;

interface

uses
  // Delphi
  System.SysUtils,
  System.JSON,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // Web3
  web3,
  web3.json,
  web3.json.rpc,
  web3.utils;

const
  BLOCK_EARLIEST = 'earliest';
  BLOCK_LATEST   = 'latest';
  BLOCK_PENDING  = 'pending';

type
  TAddress = string[42];
  TArg     = array[0..31] of Byte;
  TTuple   = TArray<TArg>;

const
  ADDRESS_NULL: TAddress = '0x0000000000000000000000000000000000000000';

type
  TASyncQuantity = reference to procedure(qty: BigInteger; err: Exception);
  TAsyncTuple    = reference to procedure(tup: TTuple; err: Exception);

procedure getBalance(client: TWeb3; address: TAddress; callback: TASyncQuantity); overload;
procedure getBalance(client: TWeb3; address: TAddress; const block: string; callback: TASyncQuantity); overload;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TASyncString); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TASyncString); overload;
procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TASyncString); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TASyncString); overload;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TASyncTuple); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TASyncTuple); overload;
procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TASyncTuple); overload;
procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TASyncTuple); overload;

implementation

procedure getBalance(client: TWeb3; address: TAddress; callback: TASyncQuantity);
begin
  getBalance(client, address, BLOCK_LATEST, callback);
end;

procedure getBalance(client: TWeb3; address: TAddress; const block: string; callback: TASyncQuantity);
begin
  web3.json.rpc.Send(client.URL, 'eth_getBalance', [address, block], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.GetPropAsStr(resp, 'result'), nil);
  end);
end;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TASyncString);
begin
  call(client, ADDRESS_NULL, &to, func, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TASyncString);
begin
   call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TASyncString);
begin
  call(client, ADDRESS_NULL, &to, func, block, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TASyncString);

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
  data: TBytes;
  obj : TJsonObject;
begin
  // step #1: encode the args into a byte array
  data := encodeArgs(args);
  // step #2: the first four bytes specify the function to be called
  web3.utils.sha3(client, web3.utils.toHex(func), procedure(const str: string; err: Exception)
  begin
    if Assigned(err) then
      callback('', err)
    else
    begin
      data := Copy(web3.utils.fromHex(str), 0, 4) + data;
      // step #3: construct the transaction call object
      obj := web3.json.Unmarshal(Format(
        '{"from": %s, "to": %s, "data": %s}', [
          web3.json.QuoteString(string(from), '"'),
          web3.json.QuoteString(string(&to), '"'),
          web3.json.QuoteString(web3.utils.toHex(data), '"')
        ]
      ));
      try
        // step #4: execute a message call (without creating a transaction on the blockchain)
        web3.json.rpc.Send(client.URL, 'eth_call', [obj, block], procedure(resp: TJsonObject; err: Exception)
        begin
          if Assigned(err) then
            callback('', err)
          else
            callback(web3.json.GetPropAsStr(resp, 'result'), nil);
        end);
      finally
        obj.Free;
      end;
    end;
  end);
end;

procedure call(client: TWeb3; &to: TAddress; const func: string; args: array of const; callback: TASyncTuple);
begin
  call(client, ADDRESS_NULL, &to, func, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func: string; args: array of const; callback: TASyncTuple);
begin
  call(client, from, &to, func, BLOCK_LATEST, args, callback);
end;

procedure call(client: TWeb3; &to: TAddress; const func, block: string; args: array of const; callback: TASyncTuple);
begin
  call(client, ADDRESS_NULL, &to, func, block, args, callback);
end;

procedure call(client: TWeb3; from, &to: TAddress; const func, block: string; args: array of const; callback: TASyncTuple);
var
  buf: TBytes;
  tup: TTuple;
begin
  call(client, from, &to, func, block, args, procedure(const hex: string; err: Exception)
  begin
    if Assigned(err) then
      callback([], err)
    else
    begin
      buf := web3.utils.fromHex(hex);
      while Length(buf) >= 32 do
      begin
        SetLength(tup, Length(tup) + 1);
        Move(buf[0], tup[High(tup)][0], 32);
        Delete(buf, 0, 32);
      end;
      callback(tup, nil);
    end;
  end);
end;

end.
