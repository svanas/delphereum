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
  System.SysUtils;

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
  EWeb3 = class(Exception);

  IError = interface
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
    function CanSignTransaction: Boolean;

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
{$IFDEF FMX}
  FMX.Dialogs
{$ELSE}
  VCL.Dialogs
{$ENDIF};

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

function TWeb3.CanSignTransaction: Boolean;
resourcestring
  RS_SIGNATURE_REQUEST = 'Your signature is being requested.'
        + #13#10#13#10 + 'Do you approve of this request?';
var
  MR: Integer;
begin
  Result := False;

  if Assigned(FOnSignatureRequest) then
  begin
    FOnSignatureRequest(Result);
    EXIT;
  end;

  TThread.Synchronize(nil, procedure
  begin
    MR := MessageDlg(
      RS_SIGNATURE_REQUEST, TMsgDlgType.mtConfirmation, mbYesNo, 0, TMsgDlgBtn.mbNo
    );
  end);

  Result := MR = mrYes;
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
