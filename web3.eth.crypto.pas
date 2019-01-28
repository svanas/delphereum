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

unit web3.eth.crypto;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // CryptoLib4Pascal
  ClpCryptoLibTypes,
  ClpDigestUtilities,
  ClpHMacDsaKCalculator,
  ClpIECPrivateKeyParameters,
  // web3
  web3.crypto,
  web3.eth.types,
  web3.utils;

type
  TEthereumSigner = class(TECDsaSignerEx)
  public
    constructor Create;
    function GenerateSignature(const msg: TCryptoLibByteArray): TECDsaSignature; reintroduce;
  end;

function PrivateKeyFromHex(aPrivKey: TPrivateKey): IECPrivateKeyParameters;
function AddressFromPrivateKey(aPrivKey: IECPrivateKeyParameters): TAddress;

implementation

function PrivateKeyFromHex(aPrivKey: TPrivateKey): IECPrivateKeyParameters;
begin
  Result := web3.crypto.PrivateKeyFromByteArray(SECP256K1, fromHex(string(aPrivKey)));
end;

function AddressFromPrivateKey(aPrivKey: IECPrivateKeyParameters): TAddress;
var
  PubKey: TBytes;
  Buffer: TBytes;
begin
  PubKey := web3.crypto.PublicKeyFromPrivateKey(aPrivKey);
  Buffer := web3.utils.sha3(PubKey);
  Delete(Buffer, 0, 12);
  Result := TAddress(toHex(Buffer));
end;

{ TEthereumSigner }

constructor TEthereumSigner.Create;
begin
  inherited Create(THMacDsaKCalculator.Create(TDigestUtilities.GetDigest('SHA-256')));
end;

function TEthereumSigner.GenerateSignature(const msg: TCryptoLibByteArray): TECDsaSignature;
begin
  Result := inherited GenerateSignature(SECP256K1, msg);
end;

end.
