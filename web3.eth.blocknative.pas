unit web3.eth.blocknative;

interface

uses
  // web3
  web3;

function getNetwork(const chain: TChain): IResult<string>;

implementation

function getNetwork(const chain: TChain): IResult<string>;
begin
  if chain = Ethereum then
    Result := TResult<string>.Ok('main')
  else if chain = Sepolia then
    Result := TResult<string>.Ok('sepolia')
  else if chain = BNB then
    Result := TResult<string>.Ok('bsc-main')
  else if chain = Gnosis then
    Result := TResult<string>.Ok('xdai')
  else if chain = Polygon then
    Result := TResult<string>.Ok('matic-main')
  else if chain = Fantom then
    Result := TResult<string>.Ok('fantom-main')
  else
    Result := TResult<string>.Err(TError.Create('%s not supported', [chain.Name]));
end;

end.
