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
  // Delphi
  System.SysUtils,
  // CryptoLib4Pascal
  ClpBigInteger,
  ClpBigIntegers,
  ClpCryptoLibTypes,
  ClpDigestUtilities,
  ClpECAlgorithms,
  ClpECDomainParameters,
  ClpECPublicKeyParameters,
  ClpIECC,
  ClpIECPublicKeyParameters,
  ClpHMacDsaKCalculator,
  ClpX9ECC,
  // web3
  web3,
  web3.crypto,
  web3.eth,
  web3.eth.types,
  web3.utils;

type
  TEthereumSigner = class(TECDsaSignerEx)
  public
    constructor Create;
    function GenerateSignature(const msg: TCryptoLibByteArray): TECDsaSignature; reintroduce;
  end;

  TGetRecId = reference to function(const V: TBigInteger): IResult<Int32>;

  TSignature = record
  private
    R: TBigInteger;
    S: TBigInteger;
    V: TBigInteger;
    class function Empty: TSignature; static;
  public
    function ToHex: string;
    constructor Create(R, S, V: TBigInteger);
    class function FromHex(const hex: string): IResult<TSignature>; static;
  end;

function publicKeyToAddress(pubKey: IECPublicKeyParameters): TAddress;
function sign(privateKey: TPrivateKey; const msg: string): TSignature;
function ecrecover(const msg: string; signature: TSignature): IResult<TAddress>; overload;
function ecrecover(const data: TBytes; signature: TSignature; getRecId: TGetRecId): IResult<TAddress>; overload;

implementation

function publicKeyToAddress(pubKey: IECPublicKeyParameters): TAddress;
begin
  // take the keccak-256 hash of the public key
  var buffer := web3.utils.sha3(publicKeyToByteArray(pubKey));
  // take the last 40 characters / 20 bytes of this public key
  Delete(buffer, 0, 12);
  // hex-encode and prefix with 0x
  Result := TAddress.Create(web3.utils.toHex(buffer));
end;

// https://github.com/ethereum/go-ethereum/pull/2940
function prefix(const msg: string): TBytes;
begin
  Result := web3.utils.sha3(
    TEncoding.UTF8.GetBytes(
      #25 + 'Ethereum Signed Message:' + #10 + IntToStr(TEncoding.UTF8.GetByteCount(msg)) + msg
    )
  );
end;

// sign message, output Ethereum-specific signature
function sign(privateKey: TPrivateKey; const msg: string): TSignature;
begin
  const Signer = TEthereumSigner.Create;
  try
    Signer.Init(True, privateKey.Parameters);
    const Signature = Signer.GenerateSignature(prefix(msg));
    const v = Signature.rec.Add(TBigInteger.ValueOf(27));
    Result := TSignature.Create(Signature.r, Signature.s, v);
  finally
    Signer.Free;
  end;
end;

// recover signer from Ethereum signed message
function ecrecover(const msg: string; signature: TSignature): IResult<TAddress>;
begin
  Result := ecrecover(prefix(msg), signature, function(const V: TBigInteger): IResult<Int32>
  begin
    const B = V.ToByteArrayUnsigned;
    if Length(B) = 0 then
    begin
      Result := TResult<Int32>.Err(0, 'V is null');
      EXIT;
    end;
    var I: Int32 := B[0];
    if (I < 27) or (I > 34) then
    begin
      Result := TResult<Int32>.Err(0, 'V is out of range');
      EXIT;
    end;
    if I >= 31 then I := I - 4;
    Result := TResult<Int32>.Ok(I - 27);
  end)
end;

// recover signer from Ethereum-specific signature
function ecrecover(const data: TBytes; signature: TSignature; getRecId: TGetRecId): IResult<TAddress>;

  function decompressKey(curve: IECCurve; xBN: TBigInteger; yBit: Boolean): IECPoint;
  begin
    const compEnc = TX9IntegerConverter.IntegerToBytes(xBN, 1 + TX9IntegerConverter.GetByteLength(curve));
    if yBit then
      compEnc[0] := $03
    else
      compEnc[0] := $02;
    Result := curve.DecodePoint(compEnc);
  end;

begin
  const recId = getRecId(signature.V);
  if recId.isErr then
  begin
    Result := TResult<TAddress>.Err(EMPTY_ADDRESS, recId.Error);
    EXIT;
  end;

  const curve = web3.crypto.SECP256K1.GetCurve;
  const n = curve.n;
  const prime = curve.Curve.Field.Characteristic;
  const i = TBigInteger.ValueOf(Int64(RecId.Value) div 2);
  const x = signature.R.Add(i.Multiply(n));
  if x.CompareTo(prime) >= 0 then
  begin
    Result := TResult<TAddress>.Err(EMPTY_ADDRESS, 'an unknown error occurred');
    EXIT;
  end;

  const R = decompressKey(curve.Curve, x, (recId.Value and 1) = 1);
  if not R.Multiply(n).IsInfinity then
  begin
    Result := TResult<TAddress>.Err(EMPTY_ADDRESS, 'an unknown error occurred');
    EXIT;
  end;

  const e        = TBigInteger.Create(1, data);
  const eInv     = TBigInteger.Zero.Subtract(e).&Mod(n);
  const rInv     = signature.R.ModInverse(n);
  const srInv    = rInv.Multiply(signature.S).&Mod(n);
  const eInvrInv = rInv.Multiply(eInv).&Mod(n);
  const q = TECAlgorithms.SumOfTwoMultiplies(curve.G, eInvrInv, R, srInv).Normalize;

  const vch = q.GetEncoded;
  const yu = curve.curve.DecodePoint(vch);
  const domain = TECDomainParameters.Create(curve.curve, curve.G, curve.n, curve.H, curve.GetSeed);

  const pubKey = TECPublicKeyParameters.Create('EC', yu, domain);
  Result := TResult<TAddress>.Ok(publicKeyToAddress(pubKey));
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

{ TSignature }

constructor TSignature.Create(R, S, V: TBigInteger);
begin
  Self.R := R;
  Self.S := S;
  Self.V := V;
end;

class function TSignature.Empty: TSignature;
begin
  Result.R := TBigInteger.Zero;
  Result.S := TBigInteger.Zero;
  Result.V := TBigInteger.Zero;
end;

class function TSignature.FromHex(const hex: string): IResult<TSignature>;
begin
  const bytes = web3.utils.fromHex(hex);
  if Length(bytes) < 65 then
  begin
    Result := TResult<TSignature>.Err(TSignature.Empty, 'out of range');
    EXIT;
  end;

  var output: TSignature;
  output.R := TBigInteger.Create(1, copy(bytes, 0, 32));
  output.S := TBigInteger.Create(1, copy(bytes, 32, 32));
  output.V := TBigInteger.Create(1, copy(bytes, 64, 1));

  Result := TResult<TSignature>.Ok(output);
end;

function TSignature.ToHex: string;
begin
  var R := Self.R.ToByteArrayUnsigned;
  while Length(R) < 32 do R := [0] + R;
  var S := Self.S.ToByteArrayUnsigned;
  while Length(S) < 32 do S := [0] + S;
  var V := Self.V.ToByteArrayUnsigned;
  if Length(V) < 1 then V := [0];
  Result := web3.utils.toHex(R + S + V);
end;

end.

