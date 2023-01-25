{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2022 Stefan van As <svanas@runbox.com>              }
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

unit web3.bip39;

interface

uses
  // Delphi
  System.Classes,
  System.SysUtils;

type
  IWordList = interface
    function Get(Index: Integer): string;
    procedure LoadFromStream(Stream: TStream; Encoding: TEncoding);
  end;

  TMnemonic = record
  strict private
    FEntropy: TArray<Integer>;
    class function from8bitTo11bit(const input: TBytes): TArray<Integer>; static;
  public
    constructor Create(entropy: TBytes);
    class function English: IWordList; static;
    function ToString(const wordlist: IWordList): string;
  end;

  TWords = (Twelve, Fifteen, Eighteen, TwentyOne, TwentyFour);
  TSeed  = TBytes;

function create: TMnemonic; overload;
function create(length: TWords): TMnemonic; overload;
function seed(const sentence, passphrase: string): TSeed;

implementation

uses
  // Delphi
  System.Types,
  // CryptoLib4Pascal
  ClpConverters,
  ClpDigestUtilities,
  ClpIKeyParameter,
  ClpPkcs5S2ParametersGenerator,
  ClpSecureRandom,
  // web3
  web3.utils;

{$R 'web3.bip39.res'}

// generate a random 15-word mnemonic
function create: TMnemonic;
begin
  Result := create(Fifteen);
end;

function create(length: TWords): TMnemonic;
const
  ENTROPY: array[TWords] of Int32 = (
    128, // 12 words
    160, // 15 words
    192, // 18 words
    224, // 21 words
    256  // 24 words
  );
begin
  const rng = TSecureRandom.Create;
  try
    Result := TMnemonic.Create(rng.GenerateSeed(ENTROPY[length] div 8));
  finally
    rng.Free;
  end;
end;

// from mnemonic sentence to 64-byte seed. please note the password is optional.
function seed(const sentence, passphrase: string): TSeed;
begin
  const generator = TPkcs5S2ParametersGenerator.Create(TDigestUtilities.GetDigest('SHA-512'));
  try
    const password = TConverters.ConvertStringToBytes(sentence, TEncoding.UTF8);
    const salt = TConverters.ConvertStringToBytes('mnemonic' + passphrase, TEncoding.UTF8);
    generator.Init(password, salt, 2048);
    Result := (generator.GenerateDerivedMacParameters(512) as IKeyParameter).GetKey;
  finally
    generator.Free;
  end;
end;

{ TWordList }

type
  TWordList = class(TInterfacedObject, IWordList)
  strict private
    Inner: TStrings;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(Index: Integer): string;
    procedure LoadFromStream(Stream: TStream; Encoding: TEncoding);
  end;

constructor TWordList.Create;
begin
  inherited Create;
  Inner := TStringList.Create;
end;

destructor TWordList.Destroy;
begin
  if Assigned(Inner) then Inner.Free;
  inherited Destroy;
end;

function TWordList.Get(Index: Integer): string;
begin
  Result := Inner[Index];
end;

procedure TWordList.LoadFromStream(Stream: TStream; Encoding: TEncoding);
begin
  Inner.LoadFromStream(Stream, Encoding);
end;

{ TMnemonic }

constructor TMnemonic.Create(entropy: TBytes);
begin
  // checksum is the 1st byte of the SHA256 digest
  const checksum = web3.utils.sha256(entropy)[0];
  // reserve 1 extra byte for the checksum
  SetLength(entropy, Length(entropy) + 1);
  entropy[High(entropy)] := checksum;
  // split entropy in groups of 11 bits, each encoding a number from 0-2047
  Self.FEntropy := TMnemonic.from8bitTo11bit(entropy);
end;

// split entropy in groups of 11 bits, each encoding a number from 0-2047, serving as an index into a wordlist
class function TMnemonic.from8bitTo11bit(const input: TBytes): TArray<Integer>;
begin
  const len = (Length(input) * 8) div 11;
  SetLength(Result, len);

  var mnemAnd := 1024;
  var idx_output := 0;

  for var idx_input := 0 to High(input) do
  begin
    var byteAnd := 128;
    for var I := 0 to 7 do
    begin
      if (input[idx_input] and byteAnd) = byteAnd then
        Result[idx_output] := Result[idx_output] or mnemAnd;
      mnemAnd := mnemAnd div 2;
      byteAnd := byteAnd div 2;
      if mnemAnd < 1 then
      begin
        mnemAnd := 1024;
        Inc(idx_output);
        if idx_output >= len then
          EXIT;
      end;
    end;
  end;
end;

class function TMnemonic.English: IWordList;
begin
  Result := TWordList.Create;
  const RS = TResourceStream.Create(hInstance, 'BIP39_ENGLISH_WORDLIST', RT_RCDATA);
  try
    Result.LoadFromStream(RS, TEncoding.UTF8);
  finally
    RS.Free;
  end;
end;

// convert entropy-in-groups-of-11-bits to mnemonic sentence
function TMnemonic.ToString(const wordlist: IWordList): string;
begin
  Result := '';
  for var I := 0 to High(FEntropy) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + wordlist.Get(FEntropy[I]);
  end;
end;

end.
