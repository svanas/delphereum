unit web3.eth.crypto;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // CryptoLib4Pascal
  ClpIECPrivateKeyParameters,
  // web3
  web3.crypto,
  web3.utils;

function PrivateKeyFromByteArray(const aPrivateKey: TBytes): IECPrivateKeyParameters;
function AddressFromPrivateKey(aPrivateKey: IECPrivateKeyParameters): TBytes;

implementation

function PrivateKeyFromByteArray(const aPrivateKey: TBytes): IECPrivateKeyParameters;
begin
  Result := web3.crypto.PrivateKeyFromByteArray(SECP256K1, aPrivateKey);
end;

function AddressFromPrivateKey(aPrivateKey: IECPrivateKeyParameters): TBytes;
var
  PubKey: TBytes;
begin
  PubKey := web3.crypto.PublicKeyFromPrivateKey(aPrivateKey);
  Result := web3.utils.sha3(PubKey);
  Delete(Result, 0, 12);
end;

end.
