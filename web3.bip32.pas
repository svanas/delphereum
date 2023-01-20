{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2023 Stefan van As <svanas@runbox.com>              }
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

unit web3.bip32;

interface

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.bip39;

type
  TKey = record
  strict private
    version    : TBytes; // 4 bytes
    keyData    : TBytes; // 33 bytes
    chainCode  : TBytes; // 32 bytes
    childNumber: TBytes; // 4 bytes
    fingerprint: TBytes; // 4 bytes
    depth      : Byte;   // 1 byte
    isPrivate  : Boolean;
    function getIntermediary(childIdx: UInt32): TBytes;
    function serialize: TBytes;
  public
    constructor Create(version, keyData, chainCode, childNumber, fingerprint: TBytes; depth: Byte; isPrivate: Boolean);
    function NewChildKey(childIdx: UInt32): IResult<TKey>;
    function PublicKey: TKey;
    function ToString: string;
  end;

// creates a new master extended key
function master(const seed: web3.bip39.TSeed): TKey;

implementation

uses
  // CryptoLib4Pascal
  ClpBigInteger,
  ClpBigIntegers,
  ClpConverters,
  ClpEncoders,
  // web3
  web3.crypto,
  web3.error,
  web3.utils;

// the index of the first "hardened" child key
const firstHardenedChild: UInt32 = 2147483648;

// returns the version flag for serialized private keys
function privateWalletVersion: TBytes; inline;
begin
  Result := web3.utils.fromHex('0x0488ADE4');
end;

// returns the version flag for serialized public keys
function publicWalletVersion: TBytes; inline;
begin
  Result := web3.utils.fromHex('0x0488B21E');
end;

// adds double-sha256 checksum to the data
function addChecksum(const data: TBytes): TBytes; inline;
begin
  const digest = sha256(sha256(data));
  Result := data + Copy(digest, 0, 4);
end;

function publicKeyFromPrivateKey(key: TBytes): TBytes; inline;
begin
  const params = web3.crypto.privateKeyFromByteArray('ECDSA', SECP256K1, key);
  const pubKey = web3.crypto.publicKeyFromPrivateKey(params);
  Result := web3.crypto.compressPublicKey(pubKey);
end;

function addPrivateKeys(const key1, key2: TBytes): TBytes; inline;
begin
  var int1 := TBigInteger.Create(1, key1);
  var int2 := TBigInteger.Create(1, key2);

  const curve = web3.crypto.SECP256K1.GetCurve;

  int1 := int1.Add(int2);
  int1 := int1.&Mod(curve.N);

  Result := TBigIntegers.BigIntegerToBytes(int1, 32);
end;

function master(const seed: web3.bip39.TSeed): TKey;
begin
  const digest = hmac_sha512(seed, TConverters.ConvertStringToBytes('Bitcoin seed', TEncoding.UTF8));
  Result := TKey.Create(
    privateWalletVersion, // version
    Copy(digest, 0, 32),  // key data
    Copy(digest, 32, 32), // chain code
    [0, 0, 0, 0],         // child number
    [0, 0, 0, 0],         // fingerprint
    0,                    // depth
    True                  // is private
  );
end;

{ TKey }

constructor TKey.Create(version, keyData, chainCode, childNumber, fingerprint: TBytes; depth: Byte; isPrivate: Boolean);
begin
  Self.version     := version;
  Self.keyData     := keyData;
  Self.chainCode   := chainCode;
  Self.childNumber := childNumber;
  Self.fingerprint := fingerprint;
  Self.depth       := depth;
  Self.isPrivate   := isPrivate;
end;

// derives a child key from a given parent
function TKey.NewChildKey(childIdx: UInt32): IResult<TKey>;
begin
  var empty: TKey;

  if not Self.isPrivate then
  begin
    Result := TResult<TKey>.Err(empty, TNotImplemented.Create);
    EXIT;
  end;

  const intermediary = Self.getIntermediary(childIdx);

  Result := TResult<TKey>.Ok(
    TKey.Create(
      privateWalletVersion,                                                     // version
      addPrivateKeys(Copy(intermediary, 0, 32), Self.keyData),                  // key data
      Copy(intermediary, 32, 32),                                               // chain code
      TConverters.ReadUInt32AsBytesBE(childIdx),                                // child number
      Copy(web3.utils.hash160(publicKeyFromPrivateKey(Self.keyData)), 0, 4),    // fingerprint
      Self.depth + 1,                                                           // depth
      Self.isPrivate                                                            // is private
    )
  );
end;

// get intermediary to create keydata and chaincode from
function TKey.getIntermediary(childIdx: UInt32): TBytes;
begin
  const childIdxBytes = TConverters.ReadUInt32AsBytesBE(childIdx);

  // hardened children are based on the private key, non-hardened children are based on the public key
  var data: TBytes;
  if childIdx >= firstHardenedChild then
    data := [0] + Self.keyData
  else
    if Self.isPrivate then
      data := publicKeyFromPrivateKey(Self.keyData)
    else
      data := Self.keyData;

  data := data + childIdxBytes;

  Result := hmac_sha512(data, Self.chainCode);
end;

// this is the so-called "neuter" function
function TKey.PublicKey: TKey;
begin
  var keyData := Self.keyData;

  if Self.isPrivate then
    keyData := publicKeyFromPrivateKey(keyData);

  Result := TKey.Create(
    publicWalletVersion, // version
    keyData,             // key data
    Self.chainCode,      // chain code
    Self.childNumber,    // child number
    Self.fingerprint,    // fingerprint
    Self.depth,          // depth
    False                // is private
  );
end;

// serializes the key to a 78-byte array
function TKey.serialize: TBytes;
begin
  // private keys should be prepended with a single null byte
  var keyData := Self.keyData;
  if Self.isPrivate then keyData := [0] + keyData;
  // write fields in order
  Result := Self.version;
  Result := Result + [Self.depth];
  Result := Result + Self.fingerprint;
  Result := Result + Self.childNumber;
  Result := Result + Self.chainCode;
  Result := Result + keyData;
  // append the double-sha256 checksum
  Result := addChecksum(Result);
end;

// encodes the key in the standard Bitcoin base58 encoding
function TKey.ToString: string;
begin
  Result := TBase58.Encode(Self.serialize);
end;

end.
