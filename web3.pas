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

unit web3;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  TChain = (
    Mainnet,
    Ropsten,
    Rinkeby,
    Goerli,
    Kovan,
    Ganache
  );

const
  chainId: array[TChain] of Integer = (
    1,   // Mainnet
    3,   // Ropsten
    4,   // Rinkeby
    5,   // Goerli
    42,  // Kovan
    1    // Ganache
  );

type
  TAddress    = string[42];
  TPrivateKey = string[64];
  TSignature  = string[132];
  TWei        = BigInteger;
  TTxHash     = string[66];

type
  EWeb3 = class(Exception);

  IError = interface
  ['{562C0444-B452-4552-9242-62E02B5D6DD0}']
    function Message: string;
  end;

  TError = class(TInterfacedObject, IError)
  private
    FMessage: string;
  public
    constructor Create(const Msg: string); overload;
    constructor Create(const Msg: string; const Args: array of const); overload;
    function Message: string;
  end;

  TSignatureDenied    = class(TError);
  TOnSignatureRequest = reference to procedure(var Approve: Boolean);

  TWeb3 = record
  private
    FChain: TChain;
    FURL  : string;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    function CanSignTransaction(account: TAddress; gasPrice: TWei): Boolean;

    class function New(const aURL: string): TWeb3; overload; static;
    class function New(aChain: TChain; const aURL: string): TWeb3; overload; static;

    class function New(const aURL: string;
      aSignatureRequest: TOnSignatureRequest): TWeb3; overload; static;
    class function New(aChain: TChain; const aURL: string;
      aSignatureRequest: TOnSignatureRequest): TWeb3; overload; static;

    property URL  : string read FURL;
    property Chain: TChain read FChain;
  end;

implementation

// https://www.ideasawakened.com/post/writing-cross-framework-code-in-delphi
uses
  System.Classes,
  System.UITypes,
  System.TypInfo,
{$IFDEF FMX}
  FMX.Dialogs,
{$ELSE}
  VCL.Dialogs,
{$ENDIF}
  web3.eth.utils;

{ TError }

constructor TError.Create(const Msg: string);
begin
  FMessage := Msg;
end;

constructor TError.Create(const Msg: string; const Args: array of const);
begin
  FMessage := Format(Msg, Args);
end;

function TError.Message: string;
begin
  Result := FMessage;
end;

{ TWeb3 }

function TWeb3.CanSignTransaction(account: TAddress; gasPrice: TWei): Boolean;
resourcestring
  RS_SIGNATURE_REQUEST = 'Your signature is being requested.'
        + #13#10#13#10 + 'Network'   + #9 + ': %s'
              + #13#10 + 'Address'   + #9 + ': %s'
              + #13#10 + 'Gas price' + #9 + ': %s Gwei'
        + #13#10#13#10 + 'Do you approve of this request?';
var
  chainName  : string;
  modalResult: Integer;
begin
  Result := False;

  if Assigned(FOnSignatureRequest) then
  begin
    FOnSignatureRequest(Result);
    EXIT;
  end;

  chainName := GetEnumName(TypeInfo(TChain), Ord(Chain));
  TThread.Synchronize(nil, procedure
  begin
    modalResult := MessageDlg(Format(RS_SIGNATURE_REQUEST,
      [chainName, account, fromWei(gasPrice, gwei)]),
      TMsgDlgType.mtConfirmation, mbYesNo, 0, TMsgDlgBtn.mbNo
    );
  end);

  Result := modalResult = mrYes;
end;

class function TWeb3.New(const aURL: string): TWeb3;
begin
  Result := New(Mainnet, aURL);
end;

class function TWeb3.New(aChain: TChain; const aURL: string): TWeb3;
begin
  Result := New(aChain, aURL, nil);
end;

class function TWeb3.New(const aURL: string;
  aSignatureRequest: TOnSignatureRequest): TWeb3;
begin
  Result := New(Mainnet, aURL, aSignatureRequest);
end;

class function TWeb3.New(aChain: TChain; const aURL: string;
  aSignatureRequest: TOnSignatureRequest): TWeb3;
begin
  Result.FChain := aChain;
  Result.FURL   := aURL;
  Result.FOnSignatureRequest := aSignatureRequest;
end;

end.
