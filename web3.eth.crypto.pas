{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{             Distributed under GNU AGPL v3.0 with Commons Clause              }
{                                                                              }
{   This program is free software: you can redistribute it and/or modify       }
{   it under the terms of the GNU Affero General Public License as published   }
{   by the Free Software Foundation, either version 3 of the License, or       }
{   (at your option) any later version.                                        }
{                                                                              }
{   This program is distributed in the hope that it will be useful,            }
{   but WITHOUT ANY WARRANTY; without even the implied warranty of             }
{   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              }
{   GNU Affero General Public License for more details.                        }
{                                                                              }
{   You should have received a copy of the GNU Affero General Public License   }
{   along with this program.  If not, see <https://www.gnu.org/licenses/>      }
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
