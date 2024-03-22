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
  TURL          = string;
  TAddress      = string[42];
  TWei          = BigInteger;
  TTxHash       = string[66];
  TUnixDateTime = Int64;
  TTransport    = (HTTPS, WebSocket);
  TSecurity     = (Automatic, TLS_10, TLS_11, TLS_12, TLS_13);
  TAssetType    = (native, erc20, erc721, erc1155);

  TChain = record
    Id       : UInt32;   // https://chainlist.org
    Name     : string;
    Symbol   : string;   // native token symbol
    TxType   : Byte;     // https://eips.ethereum.org/EIPS/eip-2718 (0 = Legacy, 2 = EIP-1559)
    RPC      : array[TTransport] of TURL;
    Explorer : TURL;     // block explorer
    Tokens   : TURL;     // Uniswap-compatible token list
    Chainlink: TAddress; // address of chainlink's Symbol/USD price feed on this chain
    WETH     : TAddress; // address of canonical WETH
    class operator Equal(const Left, Right: TChain): Boolean;
    class operator NotEqual(const Left, Right: TChain): Boolean;
    function SetTxType(const Value: Byte): TChain;
    function SetRPC(const URL: TURL): TChain; overload;
    function SetRPC(const transport: TTransport; const URL: TURL): TChain; overload;
  end;
  PChain = ^TChain;

const
  Ethereum: TChain = (
    Id       : 1;
    Name     : 'Ethereum';
    Symbol   : 'ETH';
    TxType   : 2;
    Explorer : 'https://etherscan.io';
    Tokens   : 'https://tokens.coingecko.com/uniswap/all.json';
    Chainlink: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';
    WETH     : '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
  );
  Ganache: TChain = (
    Id       : 1337;
    Name     : 'Ganache';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('http://127.0.0.1:7545', '')
  );
  Optimism: TChain = (
    Id       : 10;
    Name     : 'Optimism';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://mainnet.optimism.io', '');
    Explorer : 'https://optimistic.etherscan.io';
    Tokens   : 'https://static.optimism.io/optimism.tokenlist.json';
    Chainlink: '0x13e3Ee699D1909E989722E753853AE30b17e08c5';
    WETH     : '0x4200000000000000000000000000000000000006'
  );
  OptimismSepolia: TChain = (
    Id       : 11155420;
    Name     : 'Optimism Sepolia';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://sepolia.optimism.io', '');
    Explorer : 'https://sepolia-optimism.etherscan.io';
    Chainlink: '0x61Ec26aA57019C486B10502285c5A3D4A4750AD7';
    WETH     : '0x4200000000000000000000000000000000000006'
  );
  RSK: TChain = (
    Id       : 30;
    Name     : 'RSK';
    Symbol   : 'BTC';
    TxType   : 0;
    RPC      : ('https://public-node.rsk.co', '');
    Explorer : 'https://explorer.rsk.co'
  );
  RSK_test_net: TChain = (
    Id       : 31;
    Name     : 'RSK testnet';
    Symbol   : 'BTC';
    TxType   : 0;
    RPC      : ('https://public-node.testnet.rsk.co', '');
    Explorer : 'https://explorer.testnet.rsk.co'
  );
  BNB: TChain = (
    Id       : 56;
    Name     : 'BNB Chain';
    Symbol   : 'BNB';
    TxType   : 0;
    RPC      : ('https://bsc-dataseed.binance.org', '');
    Explorer : 'https://bscscan.com';
    Tokens   : 'https://tokens.pancakeswap.finance/pancakeswap-extended.json';
    Chainlink: '0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE';
    WETH     : '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'
  );
  BNB_test_net: TChain = (
    Id       : 97;
    Name     : 'BNB Chain testnet';
    Symbol   : 'BNB';
    TxType   : 0;
    RPC      : ('https://data-seed-prebsc-1-s1.binance.org:8545', '');
    Explorer : 'https://testnet.bscscan.com';
    Chainlink: '0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526'
  );
  Gnosis: TChain = (
    Id       : 100;
    Name     : 'Gnosis Chain';
    Symbol   : 'xDAI';
    TxType   : 2;
    RPC      : ('https://rpc.gnosischain.com', 'wss://rpc.gnosischain.com/wss');
    Explorer : 'https://gnosisscan.io/';
    Tokens   : 'https://tokens.honeyswap.org';
    Chainlink: '0x678df3415fc31947dA4324eC63212874be5a82f8';
    WETH     : '0x6A023CCd1ff6F2045C3309768eAd9E68F978f6e1'
  );
  Polygon: TChain = (
    Id       : 137;
    Name     : 'Polygon';
    Symbol   : 'MATIC';
    TxType   : 2;
    Explorer : 'https://polygonscan.com';
    Tokens   : 'https://unpkg.com/quickswap-default-token-list@latest/build/quickswap-default.tokenlist.json';
    Chainlink: '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0';
    WETH     : '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
  );
  PolygonMumbai: TChain = (
    Id       : 80001;
    Name     : 'Polygon Mumbai';
    Symbol   : 'MATIC';
    TxType   : 2;
    Explorer : 'https://mumbai.polygonscan.com';
    Chainlink: '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada'
  );
  Fantom: TChain = (
    Id       : 250;
    Name     : 'Fantom';
    Symbol   : 'FTM';
    TxType   : 0;
    RPC      : ('https://rpc.fantom.network', '');
    Explorer : 'https://ftmscan.com';
    Tokens   : 'https://raw.githubusercontent.com/SpookySwap/spooky-info/master/src/constants/token/spookyswap.json';
    Chainlink: '0xf4766552D15AE4d256Ad41B6cf2933482B0680dc';
    WETH     : '0x658b0c7613e890EE50B8C4BC6A3f41ef411208aD'
  );
  Fantom_test_net: TChain = (
    Id       : 4002;
    Name     : 'Fantom testnet';
    Symbol   : 'FTM';
    TxType   : 0;
    RPC      : ('https://rpc.testnet.fantom.network', '');
    Explorer : 'https://testnet.ftmscan.com';
    Chainlink: '0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D'
  );
  Arbitrum: TChain = (
    Id       : 42161;
    Name     : 'Arbitrum';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://arb1.arbitrum.io/rpc', '');
    Explorer : 'https://arbiscan.io';
    Tokens   : 'https://bridge.arbitrum.io/token-list-42161.json';
    Chainlink: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612';
    WETH     : '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1'
  );
  ArbitrumSepolia: TChain = (
    Id       : 421614;
    Name     : 'Arbitrum Sepolia';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://sepolia-rollup.arbitrum.io/rpc', '');
    Explorer : 'https://sepolia.arbiscan.io';
    Chainlink: '0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165'
  );
  Sepolia: TChain = (
    Id       : 11155111;
    Name     : 'Sepolia';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://rpc.sepolia.org', '');
    Explorer : 'https://sepolia.etherscan.io';
    Chainlink: '0x694AA1769357215DE4FAC081bf1f309aDC325306'
  );
  Base: TChain = (
    Id       : 8453;
    Name     : 'Base';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://mainnet.base.org', '');
    Explorer : 'https://basescan.org';
    Chainlink: '0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70';
    WETH     : '0x4200000000000000000000000000000000000006'
  );
  BaseSepolia: TChain = (
    Id       : 84532;
    Name     : 'Base Sepolia';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://sepolia.base.org', '');
    Explorer : 'https://sepolia.basescan.org';
    Chainlink: '0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1';
    WETH     : '0x4200000000000000000000000000000000000006'
  );
  PulseChain: TChain = (
    Id       : 369;
    Name     : 'PulseChain';
    Symbol   : 'PLS';
    TxType   : 2;
    RPC      : ('https://rpc.pulsechain.com', '');
    Explorer : 'https://scan.pulsechain.com';
    Tokens   : 'https://pulsechain-sacrifice-checker.vercel.app/tokens.json'
  );
  Holesky: TChain = (
    Id       : 17000;
    Name     : 'Holesky';
    Symbol   : 'ETH';
    TxType   : 2;
    Explorer : 'https://holesky.etherscan.io'
  );
  Scroll: TChain = (
    Id       : 534352;
    Name     : 'Scroll';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://rpc.scroll.io', '');
    Explorer : 'https://scrollscan.com';
    Chainlink: '0x6bF14CB0A831078629D993FDeBcB182b21A8774C';
    WETH     : '0x5300000000000000000000000000000000000004'
  );
  ScrollSepolia: TChain = (
    Id       : 534351;
    Name     : 'ScrollSepolia';
    Symbol   : 'ETH';
    TxType   : 2;
    RPC      : ('https://sepolia-rpc.scroll.io', '');
    Explorer : 'https://sepolia.scrollscan.com';
    Chainlink: '0x59F1ec1f10bD7eD9B938431086bC1D9e233ECf41';
    WETH     : '0x5300000000000000000000000000000000000004'
  );

type
  TAssetTypeHelper = record helper for TAssetType
    constructor Create(const name: string);
    function IsNFT: Boolean;
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
    function isOk: Boolean;
    function isErr: Boolean;
    function ifOk(const proc: TProc<T>): IResult<T>;
    function ifErr(const proc: TProc<IError>): IResult<T>;
    procedure &else(const proc: TProc<T>); overload;
    procedure &else(const proc: TProc<IError>); overload;
    procedure into(const callback: TProc<T, IError>);
  end;

  TResult<T> = class(TInterfacedObject, IResult<T>)
  strict private
    FValue: T;
    FError: IError;
  public
    class function Ok(const aValue: T): IResult<T>;
    class function Err(const aDefault: T; const aError: IError): IResult<T>; overload;
    class function Err(const aDefault: T; const aError: string): IResult<T>; overload;
    function Value: T;
    function Error: IError;
    function isOk: Boolean;
    function isErr: Boolean;
    function ifOk(const proc: TProc<T>): IResult<T>;
    function ifErr(const proc: TProc<IError>): IResult<T>;
    procedure &else(const proc: TProc<T>); overload;
    procedure &else(const proc: TProc<IError>); overload;
    procedure into(const callback: TProc<T, IError>);
  end;

  TOnCustomGasPrice = reference to procedure(var price: TWei);

  IJsonRpc = interface
  ['{79B99FD7-3000-4839-96B4-6C779C25AD0C}']
    function Call(
      const URL   : string;
      const method: string;
      const args  : array of const): IResult<TJsonObject>; overload;
    procedure Call(
      const URL     : string;
      const method  : string;
      const args    : array of const;
      const callback: TProc<TJsonObject, IError>); overload;
  end;

  TProxy = record
    Enabled : Boolean;
    Host    : string;
    Password: string;
    Port    : Integer;
    Username: string;
    class function Disabled: TProxy; static;
  end;

  IPubSub = interface
  ['{D63B43A1-60E4-4107-8B14-925399A4850A}']
    function Call(
      const URL     : string;
      const proxy   : TProxy;
      const security: TSecurity;
      const method  : string;
      const args    : array of const): IResult<TJsonObject>; overload;
    procedure Call(
      const URL     : string;
      const proxy   : TProxy;
      const security: TSecurity;
      const method  : string;
      const args    : array of const;
      const callback: TProc<TJsonObject, IError>); overload;

    procedure Subscribe(const subscription: string; const callback: TProc<TJsonObject, IError>);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    function OnError(const callback: TProc<IError>): IPubSub;
    function OnDisconnect(const callback: TProc): IPubSub;
  end;

  TSignatureRequestResult = reference to procedure(approved: Boolean; err: IError);
  TOnSignatureRequest     = reference to procedure(
                              const from, &to   : TAddress;
                              const gasPrice    : TWei;
                              const estimatedGas: BigInteger;
                              const callback    : TSignatureRequestResult);

  IWeb3 = interface
  ['{D4C1A132-2296-40C0-B6FB-6B326EFB8A26}']
    function Chain: TChain;
    procedure LatestPrice(const callback: TProc<Double, IError>);

    function  GetCustomGasPrice: TWei;
    procedure CanSignTransaction(
      const from, &to   : TAddress;
      const gasPrice    : TWei;
      const estimatedGas: BigInteger;
      const callback    : TSignatureRequestResult);

    function  Call(const method: string; const args: array of const): IResult<TJsonObject>; overload;
    procedure Call(const method: string; const args: array of const; const callback: TProc<TJsonObject, IError>); overload;
  end;

  TCustomWeb3 = class abstract(TInterfacedObject, IWeb3)
  private
    FChain: TChain;
    FOnCustomGasPrice: TOnCustomGasPrice;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    function Chain: TChain;
    procedure LatestPrice(const callback: TProc<Double, IError>);

    function  GetCustomGasPrice: TWei;
    procedure CanSignTransaction(
      const from, &to   : TAddress;
      const gasPrice    : TWei;
      const estimatedGas: BigInteger;
      const callback    : TSignatureRequestResult);

    function  Call(const method: string; const args: array of const): IResult<TJsonObject>; overload; virtual; abstract;
    procedure Call(const method: string; const args: array of const; const callback: TProc<TJsonObject, IError>); overload; virtual; abstract;

    property OnCustomGasPrice  : TOnCustomGasPrice   read FOnCustomGasPrice   write FOnCustomGasPrice;
    property OnSignatureRequest: TOnSignatureRequest read FOnSignatureRequest write FOnSignatureRequest;
  end;

  TWeb3 = class(TCustomWeb3)
  private
    FProtocol: IJsonRpc;
  public
    constructor Create(const aURL: TURL); overload;
    constructor Create(const aChain: TChain); overload;
    constructor Create(const aChain: TChain; const aProtocol: IJsonRpc); overload;

    function  Call(const method: string; const args: array of const): IResult<TJsonObject>; overload; override;
    procedure Call(const method: string; const args: array of const; const callback: TProc<TJsonObject, IError>); overload; override;
  end;

  IWeb3Ex = interface(IWeb3)
  ['{DD13EBE0-3E4E-49B8-A41D-B58C7DD0322F}']
    procedure Subscribe(const subscription: string; const callback: TProc<TJsonObject, IError>);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;
    function OnError(const callback: TProc<IError>): IWeb3Ex;
    function OnDisconnect(const callback: TProc): IWeb3Ex;
  end;

  TWeb3Ex = class(TCustomWeb3, IWeb3Ex)
  private
    FProtocol: IPubSub;
    FProxy   : TProxy;
    FSecurity: TSecurity;
  public
    constructor Create(
      const aURL     : TURL;
      const aProtocol: IPubSub;
      const aProxy   : TProxy;
      const aSecurity: TSecurity = TSecurity.Automatic); overload;
    constructor Create(
      const aChain   : TChain;
      const aProtocol: IPubSub;
      const aProxy   : TProxy;
      const aSecurity: TSecurity = TSecurity.Automatic); overload;

    function  Call(const method: string; const args: array of const): IResult<TJsonObject>; overload; override;
    procedure Call(const method: string; const args: array of const; const callback: TProc<TJsonObject, IError>); overload; override;

    procedure Subscribe(const subscription: string; const callback: TProc<TJsonObject, IError>);
    procedure Unsubscribe(const subscription: string);
    procedure Disconnect;

    function OnError(const callback: TProc<IError>): IWeb3Ex;
    function OnDisconnect(const callback: TProc): IWeb3Ex;
  end;

function Now: TUnixDateTime; inline;
function Infinite: BigInteger; inline;
function MaxInt256: BigInteger; inline;
function Chain(const Id: UInt32): IResult<PChain>; inline;

implementation

// https://www.ideasawakened.com/post/writing-cross-framework-code-in-delphi
uses
  System.Classes,
  System.DateUtils,
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

function Chain(const Id: UInt32): IResult<PChain>;
begin
  if Id = Ethereum.Id then
    Result := TResult<PChain>.Ok(@Ethereum)
  else if Id = Optimism.Id then
    Result := TResult<PChain>.Ok(@Optimism)
  else if Id = OptimismSepolia.Id then
    Result := TResult<PChain>.Ok(@OptimismSepolia)
  else if Id = RSK.Id then
    Result := TResult<PChain>.Ok(@RSK)
  else if Id = RSK_test_net.Id then
    Result := TResult<PChain>.Ok(@RSK_test_net)
  else if Id = BNB.Id then
    Result := TResult<PChain>.Ok(@BNB)
  else if Id = BNB_test_net.Id then
    Result := TResult<PChain>.Ok(@BNB_test_net)
  else if Id = Gnosis.Id then
    Result := TResult<PChain>.Ok(@Gnosis)
  else if Id = Polygon.Id then
    Result := TResult<PChain>.Ok(@Polygon)
  else if Id = PolygonMumbai.Id then
    Result := TResult<PChain>.Ok(@PolygonMumbai)
  else if Id = Fantom.Id then
    Result := TResult<PChain>.Ok(@Fantom)
  else if Id = Fantom_test_net.Id then
    Result := TResult<PChain>.Ok(@Fantom_test_net)
  else if Id = Arbitrum.Id then
    Result := TResult<PChain>.Ok(@Arbitrum)
  else if Id = ArbitrumSepolia.Id then
    Result := TResult<PChain>.Ok(@ArbitrumSepolia)
  else if Id = Sepolia.Id then
    Result := TResult<PChain>.Ok(@Sepolia)
  else if Id = Base.Id then
    Result := TResult<PChain>.Ok(@Base)
  else if Id = BaseSepolia.Id then
    Result := TResult<PChain>.Ok(@BaseSepolia)
  else if Id = PulseChain.Id then
    Result := TResult<PChain>.Ok(@PulseChain)
  else if Id = Holesky.Id then
    Result := TResult<PChain>.Ok(@Holesky)
  else
    Result := TResult<PChain>.Err(nil, TError.Create('Unknown chain id: %d', [Id]));
end;

{ TChain }

class operator TChain.Equal(const Left, Right: TChain): Boolean;
begin
  Result := Left.Id = Right.Id;
end;

class operator TChain.NotEqual(const Left, Right: TChain): Boolean;
begin
  Result := Left.Id <> Right.Id;
end;

function TChain.SetTxType(const Value: Byte): TChain;
begin
  Self.TxType := Value;
  Result := Self;
end;

function TChain.SetRPC(const URL: TURL): TChain;
begin
  Result := Self.SetRPC(HTTPS, URL);
end;

function TChain.SetRPC(const transport: TTransport; const URL: TURL): TChain;
begin
  Self.RPC[transport] := URL;
  Result := Self;
end;

{ TAssetTypeHelper }

constructor TAssetTypeHelper.Create(const name: string);
begin
  if SameText(name, 'ERC1155') or SameText(name, 'ERC-1155') then
    Self := erc1155
  else if SameText(name, 'ERC721') or SameText(name, 'ERC-721') then
    Self := erc721
  else if SameText(name, 'ERC20') or SameText(name, 'ERC-20') then
    Self := erc20
  else
    Self := native; // probably ETH, otherwise BNB or MATIC maybe
end;

function TAssetTypeHelper.IsNFT: Boolean;
begin
  Result := Self in [erc721, erc1155];
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

class function TResult<T>.Ok(const aValue: T): IResult<T>;
begin
  const output = TResult<T>.Create;
  output.FValue := aValue;
  output.FError := nil;
  Result := output;
end;

class function TResult<T>.Err(const aDefault: T; const aError: IError): IResult<T>;
begin
  const output = TResult<T>.Create;
  output.FValue := aDefault;
  if Assigned(aError) then
    output.FError := aError
  else
    output.FError := TError.Create('an unknown error occurred');
  Result := output;
end;

class function TResult<T>.Err(const aDefault: T; const aError: string): IResult<T>;
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

function TResult<T>.isOk: Boolean;
begin
  Result := not isErr;
end;

function TResult<T>.isErr: Boolean;
begin
  Result := Assigned(FError);
end;

function TResult<T>.ifOk(const proc: TProc<T>): IResult<T>;
begin
  Result := Self;
  if Self.isOk then proc(Self.Value);
end;

function TResult<T>.ifErr(const proc: TProc<IError>): IResult<T>;
begin
  Result := Self;
  if Self.isErr then proc(Self.Error);
end;

procedure TResult<T>.&else(const proc: TProc<T>);
begin
  if Self.isOk then proc(Self.Value);
end;

procedure TResult<T>.&else(const proc: TProc<IError>);
begin
  if Self.isErr then proc(Self.Error);
end;

procedure TResult<T>.into(const callback: TProc<T, IError>);
begin
  callback(Self.Value, Self.Error);
end;

{ TCustomWeb3 }

function TCustomWeb3.Chain: TChain;
begin
  Result := Self.FChain;
end;

// returns the chain�s latest native token price in USD (eg. ETH-USD for Ethereum, BNB-USD for BNB Chain, MATIC-USD for Polygon, etc)
procedure TCustomWeb3.LatestPrice(const callback: TProc<Double, IError>);
begin
  const coincap = procedure(const chain: TChain)
  begin
    if not chain.Symbol.IsEmpty then
      web3.coincap.price(chain.Symbol, callback)
    else
      callback(0, TError.Create('Price feed does not exist on %s', [chain.Name]));
  end;
  if Self.Chain.Chainlink.IsZero then
    coincap(Self.Chain)
  else
    web3.eth.chainlink.TAggregatorV3.Create(Self, Self.Chain.Chainlink).Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then
        coincap(Self.Chain)
      else
        callback(price, nil);
    end)
end;

function TCustomWeb3.GetCustomGasPrice: TWei;
begin
  Result := 0;
  if Assigned(FOnCustomGasPrice) then FOnCustomGasPrice(Result);
end;

procedure TCustomWeb3.CanSignTransaction(
  const from, &to   : TAddress;
  const gasPrice    : TWei;
  const estimatedGas: BigInteger;
  const callback    : TSignatureRequestResult);
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
              dotToFloat(fromWei(estimatedGas * gasPrice, ether)) * price // Gas fee
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

constructor TWeb3.Create(const aURL: TURL);
begin
  Self.Create(Ethereum.SetRPC(HTTPS, aURL));
end;

constructor TWeb3.Create(const aChain: TChain);
begin
  Self.Create(aChain, TJsonRpcHttps.Create);
end;

constructor TWeb3.Create(const aChain: TChain; const aProtocol: IJsonRpc);
begin
  Self.FChain    := aChain;
  Self.FProtocol := aProtocol;
end;

function TWeb3.Call(const method: string; const args: array of const): IResult<TJsonObject>;
begin
  Result := Self.FProtocol.Call(Self.Chain.RPC[HTTPS], method, args);
end;

procedure TWeb3.Call(const method: string; const args: array of const; const callback: TProc<TJsonObject, IError>);
begin
  Self.FProtocol.Call(Self.Chain.RPC[HTTPS], method, args, callback);
end;

{ TProxy }

class function TProxy.Disabled: TProxy;
begin
  Result.Enabled := False;
end;

{ TWeb3Ex }

constructor TWeb3Ex.Create(
  const aURL     : TURL;
  const aProtocol: IPubSub;
  const aProxy   : TProxy;
  const aSecurity: TSecurity);
begin
  Self.Create(Ethereum.SetRPC(WebSocket, aURL), aProtocol, aProxy, aSecurity);
end;

constructor TWeb3Ex.Create(
  const aChain   : TChain;
  const aProtocol: IPubSub;
  const aProxy   : TProxy;
  const aSecurity: TSecurity);
begin
  Self.FChain    := aChain;
  Self.FProtocol := aProtocol;
  Self.FProxy    := aProxy;
  Self.FSecurity := aSecurity;
end;

function TWeb3Ex.Call(const method: string; const args: array of const): IResult<TJsonObject>;
begin
  Result := Self.FProtocol.Call(Self.Chain.RPC[WebSocket], Self.FProxy, Self.FSecurity, method, args);
end;

procedure TWeb3Ex.Call(const method: string; const args: array of const; const callback: TProc<TJsonObject, IError>);
begin
  Self.FProtocol.Call(Self.Chain.RPC[WebSocket], Self.FProxy, Self.FSecurity, method, args, callback);
end;

procedure TWeb3Ex.Subscribe(const subscription: string; const callback: TProc<TJsonObject, IError>);
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

function TWeb3Ex.OnError(const callback: TProc<IError>): IWeb3Ex;
begin
  Self.FProtocol.OnError(callback);
  Result := Self;
end;

function TWeb3Ex.OnDisconnect(const callback: TProc): IWeb3Ex;
begin
  Self.FProtocol.OnDisconnect(callback);
  Result := Self;
end;

end.
