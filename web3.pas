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

  TSignatureDenied        = class(TError);
  TSignatureRequestResult = reference to procedure(approved: Boolean; err: IError);
  TOnSignatureRequest     = reference to procedure(from, &to: TAddress;
                            gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);

  TWeb3 = record
  private
    FChain: TChain;
    FURL  : string;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    procedure CanSignTransaction(from, &to: TAddress;
      gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);

    class function New(const aURL: string): TWeb3; overload; static;
    class function New(aChain: TChain; const aURL: string): TWeb3; overload; static;

    property URL  : string read FURL;
    property Chain: TChain read FChain;

    property OnSignatureRequest: TOnSignatureRequest
                                 read FOnSignatureRequest write FOnSignatureRequest;
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
  web3.eth.types,
  web3.eth.utils,
  web3.eth.infura;

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

procedure TWeb3.CanSignTransaction(from, &to: TAddress;
  gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);
resourcestring
  RS_SIGNATURE_REQUEST = 'Your signature is being requested.'
        + #13#10#13#10 + 'Network'   + #9 + ': %s'
              + #13#10 + 'From'      + #9 + ': %s'
              + #13#10 + 'To'        + #9 + ': %s'
              + #13#10 + 'Gas price' + #9 + ': %s Gwei'
              + #13#10 + 'Estimate'  + #9 + ': %s gas units'
              + #13#10 + 'Gas fee'   + #9 + ': $ %.2f'
        + #13#10#13#10 + 'Do you approve of this request?';
var
  client     : TWeb3;
  chainName  : string;
  modalResult: Integer;
begin
  if Assigned(FOnSignatureRequest) then
  begin
    FOnSignatureRequest(from, &to, gasPrice, estimatedGas, callback);
    EXIT;
  end;

  client    := Self;
  chainName := GetEnumName(TypeInfo(TChain), Ord(Chain));

  from.ToString(client, procedure(const from: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(False, err);
      EXIT;
    end;
    &to.ToString(client, procedure(const &to: string; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(False, err);
        EXIT;
      end;
      web3.eth.infura.ticker('ethusd', procedure(ticker: ITicker; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(False, err);
          EXIT;
        end;
        TThread.Synchronize(nil, procedure
        begin
          modalResult := MessageDlg(Format(RS_SIGNATURE_REQUEST, [chainName,
            from, &to, fromWei(gasPrice, gwei, 1), estimatedGas.ToString,
            ethToFloat(fromWei(estimatedGas * gasPrice, ether)) * ticker.Ask]),
            TMsgDlgType.mtConfirmation, mbYesNo, 0, TMsgDlgBtn.mbNo
          );
        end);
        callback(modalResult = mrYes, nil);
      end);
    end);
  end);
end;

class function TWeb3.New(const aURL: string): TWeb3;
begin
  Result := New(Mainnet, aURL);
end;

class function TWeb3.New(aChain: TChain; const aURL: string): TWeb3;
begin
  Result.FChain := aChain;
  Result.FURL   := aURL;
end;

end.
