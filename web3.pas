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
  System.JSON,
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  TChain = (
    Mainnet,
    Ropsten,
    Rinkeby,
    Goerli,
    Optimism,
    RSK_main_net,
    RSK_test_net,
    Kovan,
    BSC_main_net,
    BSC_test_net,
    xDai
  );

  TChainHelper = record helper for TChain
    function Id: Integer;
    function Name: string;
    function Testnet: Boolean;
    function Ethereum: Boolean;
    function BlockExplorerURL: string;
  end;

  TAddress      = string[42];
  TPrivateKey   = string[64];
  TSignature    = string[132];
  TWei          = BigInteger;
  TTxHash       = string[66];
  TUnixDateTime = Int64;
  TProtocol     = (HTTPS, WebSockets);
  TSecurity     = (Automatic, TLS_10, TLS_11, TLS_12, TLS_13);

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
    function Message: string; virtual;
  end;

  TOnEtherscanApiKey = reference to procedure(var apiKey: string);

  TGasPrice = (
    Outbid,
    Fastest,
    Fast,    // expected to be mined in < 2 minutes
    Average, // expected to be mined in < 5 minutes
    SafeLow  // expected to be mined in < 30 minutes
  );

  TGasStationInfo = record
    Speed : TGasPrice;
    apiKey: string;
    Custom: TWei;
    class function Average: TGasStationInfo; static;
  end;
  TOnGasStationInfo = reference to procedure(var info: TGasStationInfo);

  INotImplemented = interface(IError)
  ['{FFB9DA94-0C40-4A7C-9C47-CD790E3435A2}']
  end;
  TNotImplemented = class(TError, INotImplemented)
  public
    constructor Create;
  end;

  TAsyncError      = reference to procedure(err : IError);
  TAsyncJsonObject = reference to procedure(resp: TJsonObject; err: IError);
  TAsyncJsonArray  = reference to procedure(resp: TJsonArray;  err: IError);

  IProtocol = interface
  ['{DC851A2E-D172-415C-9FD0-34977FD8F232}']
  end;

  IJsonRpc = interface(IProtocol)
  ['{79B99FD7-3000-4839-96B4-6C779C25AD0C}']
    function Send(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): TJsonObject; overload;
    procedure Send(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const;
      callback    : TAsyncJsonObject); overload;
  end;

  IPubSub = interface(IJsonRpc)
  ['{D63B43A1-60E4-4107-8B14-925399A4850A}']
    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    procedure SetOnError(Value: TAsyncError);
    procedure SetOnDisconnect(Value: TProc);

    property OnError: TAsyncError write SetOnError;
    property OnDisconnect: TProc write SetOnDisconnect;
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
    FChain   : TChain;
    FURL     : string;
    FProtocol: IProtocol;
    FSecurity: TSecurity;
    FOnGasStationInfo  : TOnGasStationInfo;
    FOnEtherscanApiKey : TOnEtherscanApiKey;
    FOnSignatureRequest: TOnSignatureRequest;
    function GetJsonRpc: IJsonRpc;
    function GetPubSub : IPubSub;
  public
    function  ETHERSCAN_API_KEY: string;
    function  GetGasStationInfo: TGasStationInfo;
    procedure CanSignTransaction(from, &to: TAddress;
      gasPrice, estimatedGas: TWei; callback: TSignatureRequestResult);

    constructor Create(
      const aURL: string;
      aSecurity : TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      aChain    : TChain;
      const aURL: string;
      aSecurity : TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      const aURL: string;
      aJsonRpc  : IJsonRpc;
      aSecurity : TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      aChain    : TChain;
      const aURL: string;
      aProtocol : IProtocol;
      aSecurity : TSecurity = TSecurity.Automatic); overload;

    property Chain   : TChain    read FChain;
    property URL     : string    read FURL;
    property JsonRpc : IJsonRpc  read GetJsonRpc;
    property PubSub  : IPubSub   read GetPubSub;
    property Security: TSecurity read FSecurity;

    property OnGasStationInfo  : TOnGasStationInfo   read FOnGasStationInfo   write FOnGasStationInfo;
    property OnEtherscanApiKey : TOnEtherscanApiKey  read FOnEtherscanApiKey  write FOnEtherscanApiKey;
    property OnSignatureRequest: TOnSignatureRequest read FOnSignatureRequest write FOnSignatureRequest;
  end;

function Now: TUnixDateTime;

implementation

// https://www.ideasawakened.com/post/writing-cross-framework-code-in-delphi
uses
  System.Classes,
  System.DateUtils,
  System.TypInfo,
  System.UITypes,
{$IFDEF FMX}
  FMX.Dialogs,
{$ELSE}
  VCL.Dialogs,
{$ENDIF}
  web3.eth.chainlink,
  web3.eth.types,
  web3.eth.utils,
  web3.json.rpc.https;

function Now: TUnixDateTime;
begin
  Result := DateTimeToUnix(System.SysUtils.Now, False);
end;

{ TChainHelper }

function TChainHelper.Id: Integer;
const
  // https://chainid.network/
  CHAIN_ID: array[TChain] of Integer = (
    1,  // Mainnet
    3,  // Ropsten
    4,  // Rinkeby
    5,  // Goerli
    10, // Optimism
    30, // RSK_main_net
    31, // RSK_test_net
    42, // Kovan
    56, // BSC_main_net
    97, // BSC_test_net
    100 // xDai
  );
begin
  Result := CHAIN_ID[Self];
end;

function TChainHelper.Name: string;
begin
  Result := GetEnumName(TypeInfo(TChain), Integer(Self)).Replace('_', ' ');
end;

function TChainHelper.Testnet: Boolean;
begin
  Result := Self in [Ropsten, Rinkeby, Goerli, RSK_test_net, Kovan, BSC_test_net];
end;

function TChainHelper.Ethereum: Boolean;
begin
  Result := Self in [Mainnet, Ropsten, Rinkeby, Goerli, Kovan];
end;

function TChainHelper.BlockExplorerURL: string;
const
  BLOCK_EXPLORER_URL: array[TChain] of string = (
    'https://etherscan.io',            // Mainnet
    'https://ropsten.etherscan.io',    // Ropsten
    'https://rinkeby.etherscan.io',    // Rinkeby
    'https://goerli.etherscan.io',     // Goerli
    'https://mainnet.optimism.io',     // Optimism
    'https://explorer.rsk.co',         // RSK_main_net
    'https://explorer.testnet.rsk.co', // RSK_test_net
    'https://kovan.etherscan.io',      // Kovan
    'https://bscscan.com',             // BSC_main_net
    'https://testnet.bscscan.com',     // BSC_test_net
    'https://blockscout.com/poa/xdai'  // xDai
  );
begin
  Result := BLOCK_EXPLORER_URL[Self];
end;

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

{ TGasStationInfo }

class function TGasStationInfo.Average: TGasStationInfo;
begin
  Result.Speed := TGasPrice.Average;
end;

{ TWeb3 }

function TWeb3.ETHERSCAN_API_KEY: string;
begin
  Result := '';
  if Assigned(FOnEtherscanApiKey) then
    FOnEtherscanApiKey(Result);
end;

function TWeb3.GetGasStationInfo: TGasStationInfo;
begin
  Result := TGasStationInfo.Average;
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
      web3.eth.chainlink.eth_usd(client, procedure(price: Extended; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(False, err);
          EXIT;
        end;
        TThread.Synchronize(nil, procedure
        begin
{$WARN SYMBOL_DEPRECATED OFF}
          modalResult := MessageDlg(Format(
            RS_SIGNATURE_REQUEST,
            [
              chainName,                                                  // Network
              from,                                                       // From
              &to,                                                        // To
              fromWei(gasPrice, gwei, 1),                                 // Gas price (gwei)
              estimatedGas.ToString,                                      // Estimated gas (units)
              EthToFloat(fromWei(estimatedGas * gasPrice, ether)) * price // Gas fee
            ]),
            TMsgDlgType.mtConfirmation, mbYesNo, 0, TMsgDlgBtn.mbNo
          );
{$WARN SYMBOL_DEPRECATED DEFAULT}
        end);
        callback(modalResult = mrYes, nil);
      end);
    end, True);
  end, True);
end;

constructor TWeb3.Create(const aURL: string; aSecurity: TSecurity);
begin
  Self.Create(Mainnet, aURL, aSecurity);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string; aSecurity: TSecurity);
begin
  Self.Create(aChain, aURL, TJsonRpcHttps.Create, aSecurity);
end;

constructor TWeb3.Create(const aURL: string; aJsonRpc: IJsonRpc; aSecurity: TSecurity);
begin
  Self.Create(Mainnet, aURL, aJsonRpc, aSecurity);
end;

constructor TWeb3.Create(
  aChain    : TChain;
  const aURL: string;
  aProtocol : IProtocol;
  aSecurity : TSecurity);
begin
  Self.FChain    := aChain;
  Self.FURL      := aURL;
  Self.FProtocol := aProtocol;
  Self.FSecurity := aSecurity;
end;

function TWeb3.GetJsonRpc: IJsonRpc;
begin
  Result := nil;
  if Assigned(FProtocol) then
    if not Supports(FProtocol, IJsonRpc, Result) then
      Result := nil;
end;

function TWeb3.GetPubSub: IPubSub;
begin
  Result := nil;
  if Assigned(FProtocol) then
    if not Supports(FProtocol, IPubSub, Result) then
      Result := nil;
end;

end.
