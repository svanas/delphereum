unit web3.eth.simulate;

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.json;

type
  TChangeType = (Approve, Mint, Transfer);

  IAssetChange = interface
    function Asset   : TAssetType;
    function Change  : TChangeType;
    function From    : TAddress;
    function &To     : TAddress;
    function Amount  : BigInteger;
    function Contract: TAddress;
    function Name    : IResult<string>;
    function Symbol  : IResult<string>;
    function Decimals: IResult<Integer>;
    function Logo    : IResult<TURL>;
  end;

  IAssetChanges = interface(IDeserializedArray<IAssetChange>)
    function IndexOf(const contract: TAddress): Integer;
    function Incoming(const address: TAddress): IAssetChanges;
    function Outgoing(const address: TAddress): IAssetChanges;
  end;

procedure simulate(
  const alchemyApiKey,
        tenderlyAccountId,
        tenderlyProjectId,
        tenderlyaccessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);

implementation

uses
  // web3
  web3.eth.alchemy.api,
  web3.eth.tenderly;

procedure simulate(
  const alchemyApiKey,
        tenderlyAccountId,
        tenderlyProjectId,
        tenderlyaccessKey: string;
  const chain    : TChain;
  const from, &to: TAddress;
  const value    : TWei;
  const data     : string;
  const callback : TProc<IAssetChanges, IError>);
begin
  web3.eth.alchemy.api.simulate(alchemyApiKey, chain, from, &to, value, data, procedure(changes: IAssetChanges; err: IError)
  begin
    if not Assigned(err) then
      callback(changes, err)
    else
      web3.eth.tenderly.simulate(tenderlyAccountId, tenderlyProjectId, tenderlyAccessKey, chain, from, &to, value, data, callback);
  end);
end;

end.
