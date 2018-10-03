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
  web3.json.rpc;

const
  BLOCK_EARLIEST = 'earliest';
  BLOCK_LATEST   = 'latest';
  BLOCK_PENDING  = 'pending';

type
  TAddress = string[42];

type
  TASyncQuantity = reference to procedure(qty: BigInteger; err: Exception);

procedure getBalance(client: TWeb3; address: TAddress; callback: TASyncQuantity); overload;
procedure getBalance(client: TWeb3; address: TAddress; block: string; callback: TASyncQuantity); overload;

implementation

procedure getBalance(client: TWeb3; address: TAddress; callback: TASyncQuantity);
begin
  getBalance(client, address, BLOCK_LATEST, callback);
end;

procedure getBalance(client: TWeb3; address: TAddress; block: string; callback: TASyncQuantity);
begin
  web3.json.rpc.Send(client.URL, 'eth_getBalance', [address, block], procedure(resp: TJsonObject; err: Exception)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(web3.json.GetPropAsStr(resp, 'result'), nil);
  end);
end;

end.
