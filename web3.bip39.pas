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
  TMnemonic = record
  strict private
    FEntropy: TArray<Integer>;
    class function sha256(const input: TBytes): TBytes; static;
    class function from8bitTo11bit(const input: TBytes): TArray<Integer>; static;
  public
    constructor Create(entropy: TBytes);
    class function English: TStrings; static;
    function ToString(const wordlist: TStrings): string;
  end;

function create: TMnemonic;

implementation

uses
  // Delphi
  System.Hash,
  System.Types,
  // CryptoLib4Pascal
  ClpSecureRandom;

{$R 'web3.bip39.res'}

function create: TMnemonic;
begin
  const rng = TSecureRandom.Create;
  try
    Result := TMnemonic.Create(rng.GenerateSeed(16));
  finally
    rng.Free;
  end;
end;

{ TMnemonic }

constructor TMnemonic.Create(entropy: TBytes);
begin
  // reserve 1 extra byte for the checksum
  SetLength(entropy, Length(entropy) + 1);
  // checksum is the 1st byte of the SHA256 digest
  const checksum = TMnemonic.sha256(entropy)[0];
  entropy[High(entropy)] := checksum;
  // split entropy in groups of 11 bits, each encoding a number from 0-2047
  Self.FEntropy := TMnemonic.from8bitTo11bit(entropy);
end;

class function TMnemonic.sha256(const input: TBytes): TBytes;
begin
  const stream = TBytesStream.Create;
  try
    stream.Write(input, High(input));
    stream.Position := 0;
    Result := THashSHA2.GetHashBytes(stream, THashSHA2.TSHA2Version.SHA256);
  finally
    stream.Free;
  end;
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

class function TMnemonic.English: TStrings;
begin
  Result := TStringList.Create;
  const RS = TResourceStream.Create(hInstance, 'BIP39_ENGLISH_WORDLIST', RT_RCDATA);
  try
    Result.LoadFromStream(RS, TEncoding.UTF8);
  finally
    RS.Free;
  end;
end;

// convert entropy-in-groups-of-11-bits to mnemonic sentence
function TMnemonic.ToString(const wordlist: TStrings): string;
begin
  Result := '';
  for var I := 0 to High(FEntropy) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + wordlist[FEntropy[I]];
  end;
end;

end.
