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
  // CryptoLib4Pascal
  ClpCryptoLibTypes,
  ClpDigestUtilities,
  ClpHMacDsaKCalculator,
  // web3
  web3.crypto;

type
  TEthereumSigner = class(TECDsaSignerEx)
  public
    constructor Create;
    function GenerateSignature(const msg: TCryptoLibByteArray): TECDsaSignature; reintroduce;
  end;

implementation

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
