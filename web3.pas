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
  TAddress      = string[42];
  TPrivateKey   = string[64];
  TWei          = BigInteger;
  TTxHash       = string[66];
  TUnixDateTime = Int64;
  TTransport    = (HTTPS, WebSocket);
  TSecurity     = (Automatic, TLS_10, TLS_11, TLS_12, TLS_13);
  TStandard     = (erc20, erc721, erc1155);

  TChain = record
    Id           : UInt32; // https://chainlist.org
    Name         : string;
    TxType       : Byte;   // https://eips.ethereum.org/EIPS/eip-2718 (0 = Legacy, 2 = EIP-1559)
    Gateway      : array[TTransport] of string;
    BlockExplorer: string;
    TokenList    : string;
    class operator Equal(const Left, Right: TChain): Boolean;
    class operator NotEqual(const Left, Right: TChain): Boolean;
    function SetTxType(Value: Byte): TChain;
    function SetGateway(const URI: string): TChain; overload;
    function SetGateway(transport: TTransport; const URI: string): TChain; overload;
  end;
  PChain = ^TChain;

const
  Ethereum: TChain = (
    Id           : 1;
    Name         : 'Ethereum';
    TxType       : 2;
    BlockExplorer: 'https://etherscan.io';
    TokenList    : 'https://tokens.coingecko.com/uniswap/all.json'
  );
  Goerli: TChain = (
    Id           : 5;
    Name         : 'Goerli';
    TxType       : 2;
    BlockExplorer: 'https://goerli.etherscan.io';
    TokenList    : 'https://raw.githubusercontent.com/svanas/delphereum/master/web3.eth.balancer.v2.tokenlist.goerli.json'
  );
  Optimism: TChain = (
    Id           : 10;
    Name         : 'Optimism';
    TxType       : 2;
    BlockExplorer: 'https://optimistic.etherscan.io';
    TokenList    : 'https://static.optimism.io/optimism.tokenlist.json'
  );
  OptimismGoerli: TChain = (
    Id           : 420;
    Name         : 'Optimism Goerli';
    TxType       : 2;
    BlockExplorer: 'https://goerli-optimistic.etherscan.io'
  );
  RSK: TChain = (
    Id           : 30;
    Name         : 'RSK';
    TxType       : 0;
    Gateway      : ('https://public-node.rsk.co', '');
    BlockExplorer: 'https://explorer.rsk.co'
  );
  RSK_test_net: TChain = (
    Id           : 31;
    Name         : 'RSK testnet';
    TxType       : 0;
    Gateway      : ('https://public-node.testnet.rsk.co', '');
    BlockExplorer: 'https://explorer.testnet.rsk.co'
  );
  BNB: TChain = (
    Id           : 56;
    Name         : 'BNB Chain';
    TxType       : 0;
    Gateway      : ('https://bsc-dataseed.binance.org', '');
    BlockExplorer: 'https://bscscan.com';
    TokenList    : 'https://tokens.pancakeswap.finance/pancakeswap-extended.json'
  );
  BNB_test_net   : TChain = (
    Id           : 97;
    Name         : 'BNB Chain testnet';
    TxType       : 0;
    Gateway      : ('https://data-seed-prebsc-1-s1.binance.org:8545', '');
    BlockExplorer: 'https://testnet.bscscan.com';
  );
  Gnosis: TChain = (
    Id           : 100;
    Name         : 'Gnosis Chain';
    TxType       : 2;
    Gateway      : ('https://rpc.gnosischain.com', 'wss://rpc.gnosischain.com/wss');
    BlockExplorer: 'https://gnosisscan.io/';
    TokenList    : 'https://tokens.honeyswap.org'
  );
  Polygon: TChain = (
    Id           : 137;
    Name         : 'Polygon';
    TxType       : 2;
    BlockExplorer: 'https://polygonscan.com';
    TokenList    : 'https://unpkg.com/quickswap-default-token-list@latest/build/quickswap-default.tokenlist.json'
  );
  PolygonMumbai: TChain = (
    Id           : 80001;
    Name         : 'Polygon Mumbai';
    TxType       : 2;
    BlockExplorer: 'https://mumbai.polygonscan.com'
  );
  Fantom: TChain = (
    Id           : 250;
    Name         : 'Fantom';
    TxType       : 0;
    Gateway      : ('https://rpc.fantom.network', '');
    BlockExplorer: 'https://ftmscan.com';
    TokenList    : 'https://raw.githubusercontent.com/SpookySwap/spooky-info/master/src/constants/token/spookyswap.json'
  );
  Fantom_test_net: TChain = (
    Id           : 4002;
    Name         : 'Fantom testnet';
    TxType       : 0;
    Gateway      : ('https://rpc.testnet.fantom.network', '');
    BlockExplorer: 'https://testnet.ftmscan.com';
  );
  Arbitrum: TChain = (
    Id           : 42161;
    Name         : 'Arbitrum';
    TxType       : 0;
    BlockExplorer: 'https://explorer.arbitrum.io';
    TokenList    : 'https://bridge.arbitrum.io/token-list-42161.json'
  );
  ArbitrumGoerli: TChain = (
    Id           : 421613;
    Name         : 'Arbitrum Goerli';
    TxType       : 0;
    BlockExplorer: 'https://goerli-rollup-explorer.arbitrum.io';
  );
  Sepolia: TChain = (
    Id           : 11155111;
    Name         : 'Sepolia';
    TxType       : 2;
    Gateway      : ('https://rpc.sepolia.org', '');
    BlockExplorer: 'https://sepolia.etherscan.io';
  );

type
  TStandardHelper = record helper for TStandard
    constructor Create(const name: string);
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

  TOnCustomGasPrice = reference to procedure(var price: TWei);

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

  TSignatureRequestResult = reference to procedure(approved: Boolean; err: IError);
  TOnSignatureRequest     = reference to procedure(from, &to: TAddress; gasPrice: TWei;
                            estimatedGas: BigInteger; callback: TSignatureRequestResult);

  IWeb3 = interface
  ['{D4C1A132-2296-40C0-B6FB-6B326EFB8A26}']
    function Chain: TChain;
    procedure LatestPrice(callback: TProc<Double, IError>);

    function  GetCustomGasPrice: TWei;
    procedure CanSignTransaction(from, &to: TAddress; gasPrice: TWei; estimatedGas: BigInteger; callback: TSignatureRequestResult);

    function  Call(const method: string; args: array of const): IResult<TJsonObject>; overload;
    procedure Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>); overload;
  end;

  TCustomWeb3 = class abstract(TInterfacedObject, IWeb3)
  private
    FChain: TChain;
    FOnCustomGasPrice: TOnCustomGasPrice;
    FOnSignatureRequest: TOnSignatureRequest;
  public
    function Chain: TChain;
    procedure LatestPrice(callback: TProc<Double, IError>);

    function  GetCustomGasPrice: TWei;
    procedure CanSignTransaction(from, &to: TAddress; gasPrice: TWei; estimatedGas: BigInteger; callback: TSignatureRequestResult);

    function  Call(const method: string; args: array of const): IResult<TJsonObject>; overload; virtual; abstract;
    procedure Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>); overload; virtual; abstract;

    property OnCustomGasPrice  : TOnCustomGasPrice   read FOnCustomGasPrice   write FOnCustomGasPrice;
    property OnSignatureRequest: TOnSignatureRequest read FOnSignatureRequest write FOnSignatureRequest;
  end;

  TWeb3 = class(TCustomWeb3)
  private
    FProtocol: IJsonRpc;
  public
    constructor Create(const aURL: string); overload;
    constructor Create(const aURL: string; aTxType: Byte); overload;
    constructor Create(aChain: TChain); overload;
    constructor Create(aChain: TChain; aProtocol: IJsonRpc); overload;

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

function Now: TUnixDateTime; inline;
function Infinite: BigInteger; inline;
function MaxInt256: BigInteger; inline;
function Chain(Id: UInt32): IResult<PChain>; inline;

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

function Chain(Id: UInt32): IResult<PChain>;
begin
  if Id = Ethereum.Id then
    Result := TResult<PChain>.Ok(@Ethereum)
  else if Id = Goerli.Id then
    Result := TResult<PChain>.Ok(@Goerli)
  else if Id = Optimism.Id then
    Result := TResult<PChain>.Ok(@Optimism)
  else if Id = OptimismGoerli.Id then
    Result := TResult<PChain>.Ok(@OptimismGoerli)
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
  else if Id = ArbitrumGoerli.Id then
    Result := TResult<PChain>.Ok(@ArbitrumGoerli)
  else if Id = Sepolia.Id then
    Result := TResult<PChain>.Ok(@Sepolia)
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

function TChain.SetTxType(Value: Byte): TChain;
begin
  Self.TxType := Value;
  Result := Self;
end;

function TChain.SetGateway(const URI: string): TChain;
begin
  Result := Self.SetGateway(HTTPS, URI);
end;

function TChain.SetGateway(transport: TTransport; const URI: string): TChain;
begin
  Self.Gateway[transport] := URI;
  Result := Self;
end;

{ TStandardHelper }

constructor TStandardHelper.Create(const name: string);
begin
  if SameText(name, 'ERC1155') or SameText(name, 'ERC-1155') then
    Self := erc1155
  else if SameText(name, 'ERC721') or SameText(name, 'ERC-721') then
    Self := erc721
  else
    Self := erc20;
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

{ TCustomWeb3 }

function TCustomWeb3.Chain: TChain;
begin
  Result := Self.FChain;
end;

// returns the chain’s latest asset price in USD (eg. ETH-USD for Ethereum, BNB-USD for BNB Chain, MATIC-USD for Polygon, etc)
procedure TCustomWeb3.LatestPrice(callback: TProc<Double, IError>);
begin
  if Chain = Ethereum then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('ethereum', callback) else callback(price, nil);
    end)
  else if Chain = Sepolia then
    web3.coincap.price('ethereum', callback)
  else if Chain = Goerli then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('ethereum', callback) else callback(price, nil);
    end)
  else if Chain = Optimism then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x13e3Ee699D1909E989722E753853AE30b17e08c5').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('ethereum', callback) else callback(price, nil);
    end)
  else if Chain = OptimismGoerli then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('ethereum', callback) else callback(price, nil);
    end)
  else if (Chain = RSK) or (Chain = RSK_test_net) then
    web3.coincap.price('bitcoin', callback)
  else if Chain = BNB then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('binance-coin', callback) else callback(price, nil);
    end)
  else if Chain = BNB_test_net then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('binance-coin', callback) else callback(price, nil);
    end)
  else if Chain = Gnosis then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x678df3415fc31947dA4324eC63212874be5a82f8').Price(callback)
  else if Chain = Polygon then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('polygon', callback) else callback(price, nil);
    end)
  else if Chain = PolygonMumbai then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('polygon', callback) else callback(price, nil);
    end)
  else if Chain = Fantom then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0xf4766552D15AE4d256Ad41B6cf2933482B0680dc').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('fantom', callback) else callback(price, nil);
    end)
  else if Chain = Fantom_test_net then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('fantom', callback) else callback(price, nil);
    end)
  else if Chain = Arbitrum then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('ethereum', callback) else callback(price, nil);
    end)
  else if Chain = ArbitrumGoerli then
    web3.eth.chainlink.TAggregatorV3.Create(Self, '0x62CAe0FA2da220f43a51F86Db2EDb36DcA9A5A08').Price(procedure(price: Double; err: IError)
    begin
      if Assigned(err) then web3.coincap.price('ethereum', callback) else callback(price, nil);
    end)
  else
    callback(0, TError.Create('Price feed does not exist on %s', [Self.Chain.Name]));
end;

function TCustomWeb3.GetCustomGasPrice: TWei;
begin
  Result := 0;
  if Assigned(FOnCustomGasPrice) then FOnCustomGasPrice(Result);
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
  Self.Create(Ethereum.SetGateway(HTTPS, aURL));
end;

constructor TWeb3.Create(const aURL: string; aTxType: Byte);
begin
  Self.Create(Ethereum.SetGateway(HTTPS, aURL).SetTxType(aTxType));
end;

constructor TWeb3.Create(aChain: TChain);
begin
  Self.Create(aChain, TJsonRpcHttps.Create);
end;

constructor TWeb3.Create(aChain: TChain; aProtocol: IJsonRpc);
begin
  Self.FChain    := aChain;
  Self.FProtocol := aProtocol;
end;

function TWeb3.Call(const method: string; args: array of const): IResult<TJsonObject>;
begin
  Result := Self.FProtocol.Call(Self.Chain.Gateway[HTTPS], method, args);
end;

procedure TWeb3.Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>);
begin
  Self.FProtocol.Call(Self.Chain.Gateway[HTTPS], method, args, callback);
end;

{ TWeb3Ex }

constructor TWeb3Ex.Create(
  const aURL: string;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.Create(Ethereum.SetGateway(WebSocket, aURL), aProtocol, aSecurity);
end;

constructor TWeb3Ex.Create(
  const aURL: string;
  aTxType   : Byte;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.Create(Ethereum.SetGateway(WebSocket, aURL).SetTxType(aTxType), aProtocol, aSecurity);
end;

constructor TWeb3Ex.Create(
  aChain    : TChain;
  aProtocol : IPubSub;
  aSecurity : TSecurity = TSecurity.Automatic);
begin
  Self.FChain    := aChain;
  Self.FProtocol := aProtocol;
  Self.FSecurity := aSecurity;
end;

function TWeb3Ex.Call(const method: string; args: array of const): IResult<TJsonObject>;
begin
  Result := Self.FProtocol.Call(Self.Chain.Gateway[WebSocket], Self.FSecurity, method, args);
end;

procedure TWeb3Ex.Call(const method: string; args: array of const; callback: TProc<TJsonObject, IError>);
begin
  Self.FProtocol.Call(Self.Chain.Gateway[WebSocket], Self.FSecurity, method, args, callback);
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
