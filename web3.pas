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
    Kovan,
    Goerli,
    Optimism,
    Optimism_test_net,
    RSK,
    RSK_test_net,
    BSC,
    BSC_test_net,
    xDai,
    Polygon,
    Polygon_test_net,
    Fantom,
    Fantom_test_net,
    Arbitrum,
    Arbitrum_test_net
  );

  TChainHelper = record helper for TChain
    function Id: Integer;
    function Name: string;
    function TxType: Byte;
    function Ethereum: Boolean;
    function BlockExplorerURL: string;
  end;

  TAddress      = string[42];
  TPrivateKey   = string[64];
  TSignature    = string[132];
  TWei          = BigInteger;
  TTxHash       = string[66];
  TUnixDateTime = Int64;
  TProtocol     = (HTTPS, WebSocket);
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
    Fastest,
    Fast,    // expected to be mined in < 2 minutes
    Medium,  // expected to be mined in < 5 minutes
    Low      // expected to be mined in < 30 minutes
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

  IJsonRpc = interface
  ['{79B99FD7-3000-4839-96B4-6C779C25AD0C}']
    function Call(
      const URL   : string;
      const method: string;
      args        : array of const): TJsonObject; overload;
    procedure Call(
      const URL   : string;
      const method: string;
      args        : array of const;
      callback    : TAsyncJsonObject); overload;
  end;

  IPubSub = interface
  ['{D63B43A1-60E4-4107-8B14-925399A4850A}']
    function Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): TJsonObject; overload;
    procedure Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const;
      callback    : TAsyncJsonObject); overload;

    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    function OnError(callback: TAsyncError): IPubSub;
    function OnDisconnect(callback: TProc): IPubSub;
  end;

  ISignatureDenied = interface(IError)
  ['{AFFFBC21-3686-44A8-9034-2B38B3001B02}']
  end;
  TSignatureDenied = class(TError, ISignatureDenied);

  TSignatureRequestResult = reference to procedure(approved: Boolean; err: IError);
  TOnSignatureRequest     = reference to procedure(from, &to: TAddress; gasPrice: TWei;
                            estimatedGas: BigInteger; callback: TSignatureRequestResult);

  IWeb3 = interface
  ['{D4C1A132-2296-40C0-B6FB-6B326EFB8A26}']
    function Chain: TChain;
    function URL  : string;

    function  ETHERSCAN_API_KEY: string;
    function  GetGasStationInfo: TGasStationInfo;
    procedure CanSignTransaction(from, &to: TAddress; gasPrice: TWei; estimatedGas: BigInteger; callback: TSignatureRequestResult);

    function  Call(const method: string; args: array of const): TJsonObject; overload;
    procedure Call(const method: string; args: array of const; callback: TAsyncJsonObject); overload;
  end;

  TCustomWeb3 = class abstract(TInterfacedObject, IWeb3)
  private
    FChain: TChain;
    FURL  : string;

    FOnGasStationInfo  : TOnGasStationInfo;
    FOnEtherscanApiKey : TOnEtherscanApiKey;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    function Chain: TChain;
    function URL  : string;

    function  ETHERSCAN_API_KEY: string;
    function  GetGasStationInfo: TGasStationInfo;
    procedure CanSignTransaction(from, &to: TAddress; gasPrice: TWei; estimatedGas: BigInteger; callback: TSignatureRequestResult);

    function  Call(const method: string; args: array of const): TJsonObject; overload; virtual; abstract;
    procedure Call(const method: string; args: array of const; callback: TAsyncJsonObject); overload; virtual; abstract;

    property OnGasStationInfo  : TOnGasStationInfo   read FOnGasStationInfo   write FOnGasStationInfo;
    property OnEtherscanApiKey : TOnEtherscanApiKey  read FOnEtherscanApiKey  write FOnEtherscanApiKey;
    property OnSignatureRequest: TOnSignatureRequest read FOnSignatureRequest write FOnSignatureRequest;
  end;

  TWeb3 = class(TCustomWeb3)
  private
    FProtocol: IJsonRpc;
  public
    constructor Create(const aURL: string); overload;
    constructor Create(aChain: TChain; const aURL: string); overload;
    constructor Create(aChain: TChain; const aURL: string; aProtocol: IJsonRpc); overload;

    function  Call(const method: string; args: array of const): TJsonObject; overload; override;
    procedure Call(const method: string; args: array of const; callback: TAsyncJsonObject); overload; override;
  end;

  IWeb3Ex = interface(IWeb3)
  ['{DD13EBE0-3E4E-49B8-A41D-B58C7DD0322F}']
    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;
    function OnError(callback: TAsyncError): IWeb3Ex;
    function OnDisconnect(callback: TProc): IWeb3Ex;
  end;

  TWeb3Ex = class(TCustomWeb3, IWeb3Ex)
  private
    FProtocol: IPubSub;
    FSecurity: TSecurity;
  public
    constructor Create(
      const aURL: string;
      aProtocol : IPubSub;
      aSecurity : TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      aChain    : TChain;
      const aURL: string;
      aProtocol : IPubSub;
      aSecurity : TSecurity = TSecurity.Automatic); overload;

    function  Call(const method: string; args: array of const): TJsonObject; overload; override;
    procedure Call(const method: string; args: array of const; callback: TAsyncJsonObject); overload; override;

    procedure Subscribe(const subscription: string; callback: TAsyncJsonObject);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    function OnError(callback: TAsyncError): IWeb3Ex;
    function OnDisconnect(callback: TProc): IWeb3Ex;
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
    1,     // Mainnet
    3,     // Ropsten
    4,     // Rinkeby
    42,    // Kovan
    5,     // Goerli
    10,    // Optimism
    69,    // Optimism_test_net
    30,    // RSK
    31,    // RSK_test_net
    56,    // BSC
    97,    // BSC_test_net
    100,   // xDai
    137,   // Polygon,
    80001, // Polygon_test_net
    250,   // Fantom
    4002,  // Fantom_test_net
    42161, // Arbitrum
    421611 // Arbitrum_test_net
  );
begin
  Result := CHAIN_ID[Self];
end;

function TChainHelper.Name: string;
begin
  Result := GetEnumName(TypeInfo(TChain), Integer(Self)).Replace('_', ' ');
end;

function TChainHelper.TxType: Byte;
const
  // https://eips.ethereum.org/EIPS/eip-2718
  // 0 = Legacy
  // 2 = EIP-1559
  TX_TYPE: array[TChain] of Byte = (
    2, // Mainnet
    2, // Ropsten
    2, // Rinkeby
    2, // Kovan
    2, // Goerli
    2, // Optimism
    2, // Optimism_test_net
    0, // RSK
    0, // RSK_test_net
    0, // BSC
    0, // BSC_test_net
    2, // xDai
    2, // Polygon
    2, // Polygon_test_net
    0, // Fantom
    0, // Fantom_test_net
    0, // Arbitrum
    0  // Arbitrum_test_net
  );
begin
  Result := TX_TYPE[Self];
end;

function TChainHelper.Ethereum: Boolean;
begin
  Result := Self in [Mainnet, Ropsten, Rinkeby, Kovan, Goerli];
end;

function TChainHelper.BlockExplorerURL: string;
const
  BLOCK_EXPLORER_URL: array[TChain] of string = (
    'https://etherscan.io',                  // Mainnet
    'https://ropsten.etherscan.io',          // Ropsten
    'https://rinkeby.etherscan.io',          // Rinkeby
    'https://kovan.etherscan.io',            // Kovan
    'https://goerli.etherscan.io',           // Goerli
    'https://optimistic.etherscan.io',       // Optimism
    'https://kovan-optimistic.etherscan.io', // Optimism_test_net
    'https://explorer.rsk.co',               // RSK
    'https://explorer.testnet.rsk.co',       // RSK_test_net
    'https://bscscan.com',                   // BSC
    'https://testnet.bscscan.com',           // BSC_test_net
    'https://blockscout.com/xdai/mainnet/',  // xDai
    'https://polygonscan.com',               // Polygon
    'https://mumbai.polygonscan.com',        // Polygon_test_net
    'https://ftmscan.com',                   // Fantom
    'https://testnet.ftmscan.com',           // Fantom_test_net
    'https://explorer.arbitrum.io',          // Arbitrum
    'https://rinkeby-explorer.arbitrum.io'   // Arbitrum_test_net
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
  Result.Speed := TGasPrice.Medium;
end;

{ TCustomWeb3 }

function TCustomWeb3.Chain: TChain;
begin
  Result := Self.FChain;
end;

function TCustomWeb3.URL: string;
begin
  Result := Self.FURL;
end;

function TCustomWeb3.ETHERSCAN_API_KEY: string;
begin
  Result := '';
  if Assigned(FOnEtherscanApiKey) then FOnEtherscanApiKey(Result);
end;

function TCustomWeb3.GetGasStationInfo: TGasStationInfo;
begin
  Result := TGasStationInfo.Average;
  if Assigned(FOnGasStationInfo) then FOnGasStationInfo(Result);
end;

procedure TCustomWeb3.CanSignTransaction(
  from, &to   : TAddress;
  gasPrice    : TWei;
  estimatedGas: BigInteger;
  callback    : TSignatureRequestResult);
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
  client     : IWeb3;
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
      web3.eth.chainlink.eth_usd(client, procedure(price: Double; err: IError)
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

{ TWeb3 }

constructor TWeb3.Create(const aURL: string);
begin
  Self.Create(Mainnet, aURL);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string);
begin
  Self.Create(aChain, aURL, TJsonRpcHttps.Create);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string; aProtocol: IJsonRpc);
begin
  Self.FChain    := aChain;
  Self.FURL      := aURL;
  Self.FProtocol := aProtocol;
end;

function TWeb3.Call(const method: string; args: array of const): TJsonObject;
begin
  Result := Self.FProtocol.Call(Self.URL, method, args);
end;

procedure TWeb3.Call(const method: string; args: array of const; callback: TAsyncJsonObject);
begin
  Self.FProtocol.Call(Self.URL, method, args, callback);
end;

{ TWeb3Ex }

constructor TWeb3Ex.Create(
  const aURL: string;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.Create(Mainnet, aURL, aProtocol, aSecurity);
end;

constructor TWeb3Ex.Create(
  aChain    : TChain;
  const aURL: string;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.FChain    := aChain;
  Self.FURL      := aURL;
  Self.FProtocol := aProtocol;
  Self.FSecurity := aSecurity;
end;

function TWeb3Ex.Call(const method: string; args: array of const): TJsonObject;
begin
  Result := Self.FProtocol.Call(Self.URL, Self.FSecurity, method, args);
end;

procedure TWeb3Ex.Call(const method: string; args: array of const; callback: TAsyncJsonObject);
begin
  Self.FProtocol.Call(Self.URL, Self.FSecurity, method, args, callback);
end;

procedure TWeb3Ex.Subscribe(const subscription: string; callback: TAsyncJsonObject);
begin
  Self.FProtocol.Subscribe(subscription, callback);
end;

procedure TWeb3Ex.Unsubscribe(const subscription: string);
begin
  Self.FProtocol.Unsubscribe(subscription);
end;

procedure TWeb3Ex.Disconnect;
begin
  Self.FProtocol.Disconnect;
end;

function TWeb3Ex.OnError(callback: TAsyncError): IWeb3Ex;
begin
  Self.FProtocol.OnError(callback);
  Result := Self;
end;

function TWeb3Ex.OnDisconnect(callback: TProc): IWeb3Ex;
begin
  Self.FProtocol.OnDisconnect(callback);
  Result := Self;
end;

end.
