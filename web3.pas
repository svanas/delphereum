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
    Ethereum,
    Ropsten,
    Rinkeby,
    Kovan,
    Goerli,
    Optimism,
    OptimismGoerli,
    RSK,
    RSK_test_net,
    BNB,
    BNB_test_net,
    Gnosis,
    Polygon,
    PolygonMumbai,
    Fantom,
    Fantom_test_net,
    Arbitrum,
    ArbitrumRinkeby,
    Sepolia
  );

  TChainHelper = record helper for TChain
    function Id: Integer;
    function Name: string;
    function TxType: Byte;
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
  TStandard     = (erc20, erc721, erc1155);

  TStandardHelper = record helper for TStandard
    class function New(const name: string): TStandard; static;
  end;

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

  IResult<T> = interface
    function Value: T;
    function Error: IError;
    function IsOk: Boolean;
    function IsErr: Boolean;
    procedure Into(callback: TProc<T, IError>);
  end;

  TResult<T> = class(TInterfacedObject, IResult<T>)
  strict private
    FValue: T;
    FError: IError;
  public
    class function Ok(aValue: T): IResult<T>;
    class function Err(aDefault: T; aError: IError): IResult<T>; overload;
    class function Err(aDefault: T; aError: string): IResult<T>; overload;
    function Value: T;
    function Error: IError;
    function IsOk: Boolean;
    function IsErr: Boolean;
    procedure Into(callback: TProc<T, IError>);
  end;

  // You can safely ignore this error and continue execution if you want
  ISilent = interface(IError)
  ['{07D302E5-B5F2-479C-8606-574D2F8BCF4F}']
  end;
  TSilent = class(TError, ISilent);

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

  IJsonRpc = interface
  ['{79B99FD7-3000-4839-96B4-6C779C25AD0C}']
    function Call(
      const URL   : string;
      const method: string;
      args        : array of const): IResult<TJsonObject>; overload;
    procedure Call(
      const URL   : string;
      const method: string;
      args        : array of const;
      callback    : TProc<TJsonObject, IError>); overload;
  end;

  IPubSub = interface
  ['{D63B43A1-60E4-4107-8B14-925399A4850A}']
    function Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const): IResult<TJsonObject>; overload;
    procedure Call(
      const URL   : string;
      security    : TSecurity;
      const method: string;
      args        : array of const;
      callback    : TProc<TJsonObject, IError>); overload;

    procedure Subscribe(const subscription: string; callback: TProc<TJsonObject, IError>);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    function OnError(callback: TProc<IError>): IPubSub;
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
    function Chain : TChain;
    function URL   : string;
    function TxType: Byte;
    procedure LatestPrice(callback: TProc<Double, IError>);

    function  ETHERSCAN_API_KEY: string;
    function  GetGasStationInfo: TGasStationInfo;
    procedure CanSignTransaction(from, &to: TAddress; gasPrice: TWei; estimatedGas: BigInteger; callback: TSignatureRequestResult);

    function  Call(const method: string; args: array of const): IResult<TJsonObject>; overload;
    procedure Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>); overload;
  end;

  TCustomWeb3 = class abstract(TInterfacedObject, IWeb3)
  private
    FChain : TChain;
    FURL   : string;
    FTxType: Byte;

    FOnGasStationInfo  : TOnGasStationInfo;
    FOnEtherscanApiKey : TOnEtherscanApiKey;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    function Chain : TChain;
    function URL   : string;
    function TxType: Byte;
    procedure LatestPrice(callback: TProc<Double, IError>);

    function  ETHERSCAN_API_KEY: string;
    function  GetGasStationInfo: TGasStationInfo;
    procedure CanSignTransaction(from, &to: TAddress; gasPrice: TWei; estimatedGas: BigInteger; callback: TSignatureRequestResult);

    function  Call(const method: string; args: array of const): IResult<TJsonObject>; overload; virtual; abstract;
    procedure Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>); overload; virtual; abstract;

    property OnGasStationInfo  : TOnGasStationInfo   read FOnGasStationInfo   write FOnGasStationInfo;
    property OnEtherscanApiKey : TOnEtherscanApiKey  read FOnEtherscanApiKey  write FOnEtherscanApiKey;
    property OnSignatureRequest: TOnSignatureRequest read FOnSignatureRequest write FOnSignatureRequest;
  end;

  TWeb3 = class(TCustomWeb3)
  private
    FProtocol: IJsonRpc;
  public
    constructor Create(const aURL: string); overload;
    constructor Create(const aURL: string; aTxType: Byte); overload;
    constructor Create(aChain: TChain; const aURL: string); overload;
    constructor Create(aChain: TChain; const aURL: string; aTxType: Byte); overload;
    constructor Create(aChain: TChain; const aURL: string; aProtocol: IJsonRpc); overload;
    constructor Create(aChain: TChain; const aURL: string; aTxType: Byte; aProtocol: IJsonRpc); overload;

    function  Call(const method: string; args: array of const): IResult<TJsonObject>; overload; override;
    procedure Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>); overload; override;
  end;

  IWeb3Ex = interface(IWeb3)
  ['{DD13EBE0-3E4E-49B8-A41D-B58C7DD0322F}']
    procedure Subscribe(const subscription: string; callback: TProc<TJsonObject, IError>);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;
    function OnError(callback: TProc<IError>): IWeb3Ex;
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
      const aURL: string;
      aTxType   : Byte;
      aProtocol : IPubSub;
      aSecurity : TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      aChain    : TChain;
      const aURL: string;
      aProtocol : IPubSub;
      aSecurity : TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      aChain    : TChain;
      const aURL: string;
      aTxType   : Byte;
      aProtocol : IPubSub;
      aSecurity : TSecurity = TSecurity.Automatic); overload;

    function  Call(const method: string; args: array of const): IResult<TJsonObject>; overload; override;
    procedure Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>); overload; override;

    procedure Subscribe(const subscription: string; callback: TProc<TJsonObject, IError>);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    function OnError(callback: TProc<IError>): IWeb3Ex;
    function OnDisconnect(callback: TProc): IWeb3Ex;
  end;

function Now: TUnixDateTime;
function Infinite: BigInteger;
function MaxInt256: BigInteger;

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
  web3.coincap,
  web3.eth.chainlink,
  web3.eth.types,
  web3.eth.utils,
  web3.json.rpc.https;

function Now: TUnixDateTime;
begin
  Result := DateTimeToUnix(System.SysUtils.Now, False);
end;

function Infinite: BigInteger;
begin
  Result := BigInteger.Create('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF');
end;

function MaxInt256: BigInteger;
begin
  Result := BigInteger.Create('57896044618658097711785492504343953926634992332820282019728792003956564819967');
end;

{ TChainHelper }

function TChainHelper.Id: Integer;
const
  // https://chainlist.org
  CHAIN_ID: array[TChain] of Integer = (
    1,       // Ethereum
    3,       // Ropsten
    4,       // Rinkeby
    42,      // Kovan
    5,       // Goerli
    10,      // Optimism
    420,     // OptimismGoerli
    30,      // RSK
    31,      // RSK_test_net
    56,      // BNB
    97,      // BNB_test_net
    100,     // Gnosis
    137,     // Polygon,
    80001,   // PolygonMumbai
    250,     // Fantom
    4002,    // Fantom_test_net
    42161,   // Arbitrum
    421611,  // ArbitrumRinkeby
    11155111 // Sepolia
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
    2, // Ethereum
    2, // Ropsten
    2, // Rinkeby
    2, // Kovan
    2, // Goerli
    2, // Optimism
    2, // OptimismGoerli
    0, // RSK
    0, // RSK_test_net
    0, // BNB
    0, // BNB_test_net
    2, // Gnosis
    2, // Polygon
    2, // PolygonMumbai
    0, // Fantom
    0, // Fantom_test_net
    0, // Arbitrum
    0, // ArbitrumRinkeby
    2  // Sepolia
  );
begin
  Result := TX_TYPE[Self];
end;

function TChainHelper.BlockExplorerURL: string;
const
  BLOCK_EXPLORER_URL: array[TChain] of string = (
    'https://etherscan.io',                   // Ethereum
    'https://ropsten.etherscan.io',           // Ropsten
    'https://rinkeby.etherscan.io',           // Rinkeby
    'https://kovan.etherscan.io',             // Kovan
    'https://goerli.etherscan.io',            // Goerli
    'https://optimistic.etherscan.io',        // Optimism
    'https://goerli-optimistic.etherscan.io', // OptimismGoerli
    'https://explorer.rsk.co',                // RSK
    'https://explorer.testnet.rsk.co',        // RSK_test_net
    'https://bscscan.com',                    // BNB
    'https://testnet.bscscan.com',            // BNB_test_net
    'https://gnosisscan.io/',                 // Gnosis
    'https://polygonscan.com',                // Polygon
    'https://mumbai.polygonscan.com',         // PolygonMumbai
    'https://ftmscan.com',                    // Fantom
    'https://testnet.ftmscan.com',            // Fantom_test_net
    'https://explorer.arbitrum.io',           // Arbitrum
    'https://rinkeby-explorer.arbitrum.io',   // ArbitrumRinkeby
    'https://sepolia.etherscan.io'            // Sepolia
  );
begin
  Result := BLOCK_EXPLORER_URL[Self];
end;

{ TStandardHelper }

class function TStandardHelper.New(const name: string): TStandard;
begin
  if SameText(name, 'ERC1155') or SameText(name, 'ERC-1155') then
    Result := erc1155
  else if SameText(name, 'ERC721') or SameText(name, 'ERC-721') then
    Result := erc721
  else
    result := erc20;
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

{ TResult }

class function TResult<T>.Ok(aValue: T): IResult<T>;
begin
  const output = TResult<T>.Create;
  output.FValue := aValue;
  output.FError := nil;
  Result := output;
end;

class function TResult<T>.Err(aDefault: T; aError: IError): IResult<T>;
begin
  const output = TResult<T>.Create;
  output.FValue := aDefault;
  if Assigned(aError) then
    output.FError := aError
  else
    output.FError := TError.Create('an unknown error occurred');
  Result := output;
end;

class function TResult<T>.Err(aDefault: T; aError: string): IResult<T>;
begin
  Result := TResult<T>.Err(aDefault, TError.Create(aError));
end;

function TResult<T>.Value: T;
begin
  Result := FValue;
end;

function TResult<T>.Error: IError;
begin
  Result := FError;
end;

function TResult<T>.IsOk: Boolean;
begin
  Result := not IsErr;
end;

function TResult<T>.IsErr: Boolean;
begin
  Result := Assigned(FError);
end;

procedure TResult<T>.Into(callback: TProc<T, IError>);
begin
  callback(Self.Value, Self.Error);
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

function TCustomWeb3.TxType: Byte;
begin
  Result := Self.FTxType;
end;

// returns the chain�s latest asset price in USD (eg. ETH-USD for Ethereum, BNB-USD for BNB Chain, MATIC-USD for Polygon, etc)
procedure TCustomWeb3.LatestPrice(callback: TProc<Double, IError>);
begin
  case Self.Chain of
    Ethereum:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419').Price(callback);
    Ropsten, Rinkeby, Kovan, Sepolia:
      web3.coincap.price('ethereum', callback);
    Goerli:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e').Price(callback);
    Optimism:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x13e3Ee699D1909E989722E753853AE30b17e08c5').Price(callback);
    OptimismGoerli:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8').Price(callback);
    RSK, RSK_test_net:
      web3.coincap.price('bitcoin', callback);
    BNB:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e').Price(callback);
    BNB_test_net:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7').Price(callback);
    Gnosis:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x678df3415fc31947dA4324eC63212874be5a82f8').Price(callback);
    Polygon:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0').Price(callback);
    PolygonMumbai:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada').Price(callback);
    Fantom:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0xf4766552D15AE4d256Ad41B6cf2933482B0680dc').Price(callback);
    Fantom_test_net:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D').Price(callback);
    Arbitrum:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612').Price(callback);
    ArbitrumRinkeby:
      web3.eth.chainlink.TAggregatorV3.Create(Self, '0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8').Price(callback);
  else
    callback(0, TError.Create('Price feed does not exist on %s', [Self.Chain.Name]));
  end;
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
        + #13#10#13#10 + 'Network: %s'
              + #13#10 + 'From: %s'
              + #13#10 + 'To: %s'
              + #13#10 + 'Gas price: %s Gwei'
              + #13#10 + 'Gas estimate: %s units'
              + #13#10 + 'Gas fee: $ %.2f'
        + #13#10#13#10 + 'Do you approve of this request?';
begin
  if Assigned(FOnSignatureRequest) then
  begin
    FOnSignatureRequest(from, &to, gasPrice, estimatedGas, callback);
    EXIT;
  end;

  from.ToString(Self, procedure(from: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(False, err);
      EXIT;
    end;
    &to.ToString(Self, procedure(&to: string; err: IError)
    begin
      if Assigned(err) then
      begin
        callback(False, err);
        EXIT;
      end;
      Self.LatestPrice(procedure(price: Double; err: IError)
      begin
        if Assigned(err) then
        begin
          callback(False, err);
          EXIT;
        end;
        var modalResult: Integer;
        TThread.Synchronize(nil, procedure
        begin
{$WARN SYMBOL_DEPRECATED OFF}
          modalResult := MessageDlg(Format(
            RS_SIGNATURE_REQUEST,
            [
              Self.Chain.Name,                                            // Network
              from,                                                       // From
              &to,                                                        // To
              fromWei(gasPrice, gwei, 2),                                 // Gas price (gwei)
              estimatedGas.ToString,                                      // Estimated gas (units)
              DotToFloat(fromWei(estimatedGas * gasPrice, ether)) * price // Gas fee
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
  Self.Create(Ethereum, aURL);
end;

constructor TWeb3.Create(const aURL: string; aTxType: Byte);
begin
  Self.Create(Ethereum, aURL, aTxType);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string);
begin
  Self.Create(aChain, aURL, TJsonRpcHttps.Create);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string; aTxType: Byte);
begin
  Self.Create(aChain, aURL, aTxType, TJsonRpcHttps.Create);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string; aProtocol: IJsonRpc);
begin
  Self.Create(aChain, aURL, aChain.TxType, aProtocol);
end;

constructor TWeb3.Create(aChain: TChain; const aURL: string; aTxType: Byte; aProtocol: IJsonRpc);
begin
  Self.FChain    := aChain;
  Self.FURL      := aURL;
  Self.FTxType   := aTxType;
  Self.FProtocol := aProtocol;
end;

function TWeb3.Call(const method: string; args: array of const): IResult<TJsonObject>;
begin
  Result := Self.FProtocol.Call(Self.URL, method, args);
end;

procedure TWeb3.Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>);
begin
  Self.FProtocol.Call(Self.URL, method, args, callback);
end;

{ TWeb3Ex }

constructor TWeb3Ex.Create(
  const aURL: string;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.Create(Ethereum, aURL, aProtocol, aSecurity);
end;

constructor TWeb3Ex.Create(
  const aURL: string;
  aTxType   : Byte;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.Create(Ethereum, aURL, aTxType, aProtocol, aSecurity);
end;

constructor TWeb3Ex.Create(
  aChain    : TChain;
  const aURL: string;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.Create(aChain, aURL, aChain.TxType, aProtocol, aSecurity);
end;

constructor TWeb3Ex.Create(
  aChain    : TChain;
  const aURL: string;
  aTxType   : Byte;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.FChain    := aChain;
  Self.FURL      := aURL;
  Self.FTxType   := aTxType;
  Self.FProtocol := aProtocol;
  Self.FSecurity := aSecurity;
end;

function TWeb3Ex.Call(const method: string; args: array of const): IResult<TJsonObject>;
begin
  Result := Self.FProtocol.Call(Self.URL, Self.FSecurity, method, args);
end;

procedure TWeb3Ex.Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>);
begin
  Self.FProtocol.Call(Self.URL, Self.FSecurity, method, args, callback);
end;

procedure TWeb3Ex.Subscribe(const subscription: string; callback: TProc<TJsonObject, IError>);
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

function TWeb3Ex.OnError(callback: TProc<IError>): IWeb3Ex;
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
