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
    RSK_main_net,
    RSK_test_net,
    Kovan,
    Ganache
  );

const
  chainId: array[TChain] of Integer = (
    1,   // Mainnet
    3,   // Ropsten
    4,   // Rinkeby
    5,   // Goerli
    30,  // RSK_main_net
    31,  // RSK_test_net
    42,  // Kovan
    1    // Ganache
  );

type
  TAddress    = string[42];
  TPrivateKey = string[64];
  TSignature  = string[132];
  TWei        = BigInteger;
  TTxHash     = string[66];

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

  TGasPrice = (
    Fast,    // expected to be mined in < 2 minutes
    Average, // expected to be mined in < 5 minutes
    SafeLow  // expected to be mined in < 30 minutes
  );

  TGasStationInfo = record
    Speed : TGasPrice;
    apiKey: string;
  end;
  TOnGasStationInfo = reference to procedure(var info: TGasStationInfo);

  INotImplemented = interface(IError)
  ['{FFB9DA94-0C40-4A7C-9C47-CD790E3435A2}']
  end;
  TNotImplemented = class(TError, INotImplemented)
  public
    constructor Create;
  end;

  ISignatureDenied = interface(IError)
  ['{AFFFBC21-3686-44A8-9034-2B38B3001B02}']
  end;
  TSignatureDenied = class(TError, ISignatureDenied);

  TSignatureRequestResult = reference to procedure(approved: Boolean; err: IError);
  TOnSignatureRequest     = reference to procedure(from, &to: TAddress;
                            gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);

  TWeb3 = record
  private
    FChain: TChain;
    FURL  : string;
    FOnGasStationInfo  : TOnGasStationInfo;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    function  GetGasStationInfo: TGasStationInfo;
    procedure CanSignTransaction(from, &to: TAddress;
      gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);

    class function New(const aURL: string): TWeb3; overload; static;
    class function New(aChain: TChain; const aURL: string): TWeb3; overload; static;

    property URL  : string read FURL;
    property Chain: TChain read FChain;
    property OnGasStationInfo: TOnGasStationInfo
                               read FOnGasStationInfo write FOnGasStationInfo;
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

{ TNotImplemented }

constructor TNotImplemented.Create;
begin
  inherited Create('Not implemented');
end;

{ TWeb3 }

function TWeb3.GetGasStationInfo: TGasStationInfo;
begin
  Result.Speed := Average;
  if Assigned(FOnGasStationInfo) then
    FOnGasStationInfo(Result);
end;

procedure TWeb3.CanSignTransaction(from, &to: TAddress;
  gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);
resourcestring
  RS_SIGNATURE_REQUEST = 'Your signature is being requested.'
        + #13#10#13#10 + 'Network'   + #9 + ': %s'
              + #13#10 + 'From   '   + #9 + ': %s'
              + #13#10 + 'To     '   + #9 + ': %s'
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
{$WARN SYMBOL_DEPRECATED OFF}
          modalResult := MessageDlg(Format(RS_SIGNATURE_REQUEST, [chainName,
            from, &to, fromWei(gasPrice, gwei, 1), estimatedGas.ToString,
            EthToFloat(fromWei(estimatedGas * gasPrice, ether)) * ticker.Ask]),
            TMsgDlgType.mtConfirmation, mbYesNo, 0, TMsgDlgBtn.mbNo
          );
{$WARN SYMBOL_DEPRECATED DEFAULT}
        end);
        callback(modalResult = mrYes, nil);
      end);
    end, True);
  end, True);
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
