unit web3.crypto;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  System.TypInfo,
  // CryptoLib4Pascal
  ClpBigInteger,
  ClpCryptoLibTypes,
  ClpCustomNamedCurves,
  ClpIECC,
  ClpECDomainParameters,
  ClpECDsaSigner,
  ClpECKeyPairGenerator,
  ClpECPrivateKeyParameters,
  ClpIECDomainParameters,
  ClpIECPrivateKeyParameters,
  ClpIECPublicKeyParameters,
  ClpIX9ECParameters;

type
  TKeyType = (SECP256K1, SECP384R1, SECP521R1, SECT283K1);

type
  TECDsaSignature = record
    r  : TBigInteger;
    s  : TBigInteger;
    rec: TBigInteger;
  end;

type
  TECDsaSignerEx = class(TECDsaSigner)
  public
    function GenerateSignature(const msg: TCryptoLibByteArray): TECDsaSignature; reintroduce;
  end;

function PrivateKeyFromByteArray(aKeyType: TKeyType; const aPrivateKey: TBytes): IECPrivateKeyParameters;
function PublicKeyFromPrivateKey(aPrivateKey: IECPrivateKeyParameters): TBytes;

implementation

function GetCurveFromKeyType(aKeyType: TKeyType): IX9ECParameters;
var
  CurveName: string;
begin
  CurveName := GetEnumName(TypeInfo(TKeyType), Ord(aKeyType));
  Result    := TCustomNamedCurves.GetByName(CurveName);
end;

function PrivateKeyFromByteArray(aKeyType: TKeyType; const aPrivateKey: TBytes): IECPrivateKeyParameters;
var
  domain: IECDomainParameters;
  LCurve: IX9ECParameters;
  PrivD : TBigInteger;
begin
  LCurve := GetCurveFromKeyType(aKeyType);
  domain := TECDomainParameters.Create(LCurve.Curve, LCurve.G, LCurve.N, LCurve.H, LCurve.GetSeed);
  PrivD  := TBigInteger.Create(1, aPrivateKey);
  Result := TECPrivateKeyParameters.Create('ECDSA', PrivD, domain);
end;

function PublicKeyFromPrivateKey(aPrivateKey: IECPrivateKeyParameters): TBytes;
var
  Params: IECPublicKeyParameters;
begin
  Params := TECKeyPairGenerator.GetCorrespondingPublicKey(aPrivateKey);
  Result := Params.Q.AffineXCoord.ToBigInteger.ToByteArrayUnsigned
          + Params.Q.AffineYCoord.ToBigInteger.ToByteArrayUnsigned;
end;

{ TECDsaSignerEx }

function TECDsaSignerEx.GenerateSignature(const msg: TCryptoLibByteArray): TECDsaSignature;
var
  ec: IECDomainParameters;
  base: IECMultiplier;
  n, e, d, k: TBigInteger;
  p: IECPoint;
begin
  ec := Fkey.parameters;
  n := ec.n;
  e := CalculateE(n, msg);
  d := (Fkey as IECPrivateKeyParameters).d;

  if FkCalculator.IsDeterministic then
    FkCalculator.Init(n, d, msg)
  else
    FkCalculator.Init(n, Frandom);

  base := CreateBasePointMultiplier;

  repeat // Generate s
    repeat // Generate r
      k := FkCalculator.NextK;
      p := base.Multiply(ec.G, k).Normalize;
      Result.r := p.AffineXCoord.ToBigInteger.&Mod(n);
    until not(Result.r.SignValue = 0);
    Result.s := k.ModInverse(n).Multiply(e.Add(d.Multiply(Result.r))).&Mod(n);
  until not(Result.s.SignValue = 0);

  // https://ethereum.stackexchange.com/questions/42455/during-ecdsa-signing-how-do-i-generate-the-recovery-id
  Result.rec := p.AffineYCoord.ToBigInteger.&And(TBigInteger.One);
  if Result.s.CompareTo(n.Divide(TBigInteger.Two)) = 1 then
    Result.rec := Result.rec.&Xor(TBigInteger.One);
end;

end.
