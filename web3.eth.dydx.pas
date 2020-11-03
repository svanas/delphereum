{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.dydx;

{$I web3.inc}

interface

uses
  // Delphi
  System.TypInfo,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.abi,
  web3.eth.contract,
  web3.eth.defi,
  web3.eth.erc20,
  web3.eth.types,
  web3.utils;

type
  EdYdX = class(EWeb3);

  // Global helper functions
  TdYdX = class(TLendingProtocol)
  protected
    class procedure TokenAddress(
      client  : TWeb3;
      reserve : TReserve;
      callback: TAsyncAddress);
    class procedure Approve(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt);
  public
    class function Name: string; override;
    class function Supports(
      chain   : TChain;
      reserve : TReserve): Boolean; override;
    class procedure APY(
      client  : TWeb3;
      reserve : TReserve;
      _period : TPeriod;
      callback: TAsyncFloat); override;
    class procedure Deposit(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceipt); override;
    class procedure Balance(
      client  : TWeb3;
      owner   : TAddress;
      reserve : TReserve;
      callback: TAsyncQuantity); override;
    class procedure Withdraw(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      callback: TAsyncReceiptEx); override;
    class procedure WithdrawEx(
      client  : TWeb3;
      from    : TPrivateKey;
      reserve : TReserve;
      amount  : BigInteger;
      callback: TAsyncReceiptEx); override;
  end;

  TSoloTotalPar = record
    Borrow: BigInteger;
    Supply: BigInteger;
  end;

  TSoloIndex = record
    Borrow    : Extended;
    Supply    : Extended;
    LastUpdate: BigInteger;
  end;

  ISoloMarket = interface
    function Token         : TAddress;      // Contract address of the associated ERC20 token
    function TotalPar      : TSoloTotalPar; // Total aggregated supply and borrow amount of the entire market
    function Index         : TSoloIndex;    // Interest index of the market
    function PriceOracle   : TAddress;      // Contract address of the price oracle for this market
    function InterestSetter: TAddress;      // Contract address of the interest setter for this market
    function MarginPremium : Extended;      // Multiplier on the marginRatio for this market
    function SpreadPremium : Extended;      // Multiplier on the liquidationSpread for this market
    function IsClosing     : Boolean;       // Whether additional borrows are allowed for this market
  end;

  TAsyncSoloMarket = reference to procedure(market: ISoloMarket; err: IError);

  TSoloActionType = (
    Deposit,   // supply tokens
    Withdraw,  // borrow tokens
    Transfer,  // transfer balance between accounts
    Buy,       // buy an amount of some token (externally)
    Sell,      // sell an amount of some token (externally)
    Trade,     // trade tokens against another account
    Liquidate, // liquidate an undercollateralized or expiring account
    Vaporize,  // use excess tokens to zero-out a completely negative account
    Call       // send arbitrary data to an address
  );

  TSoloDenomination = (
    Wei, // the amount is denominated in wei
    Par  // the amount is denominated in par
  );

  TSoloReference = (
    Delta, // the amount is given as a delta from the current value
    Target // the amount is given as an exact number to end up at
  );

  TSoloMargin = class(TCustomContract)
  private
    const
      deployed: array[TChain] of TAddress = (
        '0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e', // Mainnet
        '',                                           // Ropsten
        '',                                           // Rinkeby
        '',                                           // Goerli
        '',                                           // RSK_main_net
        '',                                           // RSK_test_net
        '0x4EC3570cADaAEE08Ae384779B0f3A45EF85289DE', // Kovan
        '0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e'  // Ganache
      );
  protected
    class function ToBigInt(value: TTuple): BigInteger;
  public
    const
      marketId: array[TReserve] of Integer = (
        3, // DAI
        2, // USDC
        -1 // USDT
      );
    constructor Create(aClient: TWeb3); reintroduce;
    procedure GetAccountWei(owner: TAddress; marketId: Integer; callback: TAsyncQuantity);
    procedure GetEarningsRate(callback: TAsyncFloat);
    procedure GetMarket(marketId: Integer; callback: TAsyncSoloMarket);
    procedure GetMarketInterestRate(marketId: Integer; callback: TAsyncFloat);
    procedure GetMarketSupplyInterestRate(marketId: Integer; callback: TAsyncFloat);
    procedure GetMarketUtilization(marketId: Integer; callback: TAsyncFloat);
    procedure Operate(
      owner            : TPrivateKey;
      actionType       : TSoloActionType;
      amount           : BigInteger;
      denomination     : TSoloDenomination;
      reference        : TSoloReference;
      primaryMarketId  : Integer;
      secondaryMarketId: Integer;
      otherAddress     : TAddress;
      otherAccountId   : Integer;
      callback         : TAsyncReceipt);
    procedure Deposit(
      owner   : TPrivateKey;
      marketId: Integer;
      amount  : BigInteger;
      callback: TAsyncReceipt);
    procedure Withdraw(
      owner   : TPrivateKey;
      marketId: Integer;
      amount  : BigInteger;
      callback: TAsyncReceipt);
  end;

implementation

const
  INTEREST_RATE_BASE = 1e18;

{ TdYdX }

// Returns contract address of the associated ERC20 token
class procedure TdYdX.TokenAddress(
  client  : TWeb3;
  reserve : TReserve;
  callback: TAsyncAddress);
var
  dYdX: TSoloMargin;
begin
  dYdX := TSoloMargin.Create(client);
  if Assigned(dYdX) then
  try
    dYdX.GetMarket(TSoloMargin.marketId[reserve], procedure(market: ISoloMarket; err: IError)
    begin
      if Assigned(err) then
        callback(ADDRESS_ZERO, err)
      else
        callback(market.Token, nil);
    end);
  finally
    dYdX.Free;
  end;
end;

// Approve the Solo contract to move your tokens.
class procedure TdYdX.Approve(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  erc20: TERC20;
begin
  TokenAddress(client, reserve, procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
    begin
      erc20 := TERC20.Create(client, addr);
      if Assigned(erc20) then
      begin
        erc20.ApproveEx(from, TSoloMargin.deployed[client.Chain], amount, procedure(rcpt: ITxReceipt; err: IError)
        begin
          try
            callback(rcpt, err);
          finally
            erc20.Free;
          end;
        end);
      end;
    end;
  end);
end;

class function TdYdX.Name: string;
begin
  Result := 'dYdX';
end;

class function TdYdX.Supports(chain: TChain; reserve: TReserve): Boolean;
begin
  Result := (chain in [Mainnet, Ganache, Kovan]) and (reserve <> USDT);
end;

// Returns the annual yield as a percentage.
class procedure TdYdX.APY(
  client  : TWeb3;
  reserve : TReserve;
  _period : TPeriod;
  callback: TAsyncFloat);
const
  SECONDS_PER_YEAR = 31536000;
var
  dYdX: TSoloMargin;
begin
  dYdX := TSoloMargin.Create(client);
  if Assigned(dYdX) then
  begin
    dYdX.GetMarketSupplyInterestRate(TSoloMargin.marketId[reserve], procedure(qty: Extended; err: IError)
    begin
      try
        if Assigned(err) then
          callback(0, err)
        else
          callback(qty * SECONDS_PER_YEAR * 100, nil);
      finally
        dYdX.Free;
      end;
    end);
  end;
end;

class procedure TdYdX.Deposit(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceipt);
var
  dYdX: TSoloMargin;
begin
  // Before moving tokens, we must first approve the Solo contract.
  Approve(client, from, reserve, amount, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
    begin
      dYdX := TSoloMargin.Create(client);
      if Assigned(dYdX) then
      try
        dYdX.Deposit(from, TSoloMargin.marketId[reserve], amount, callback);
      finally
        dYdX.Free;
      end;
    end;
  end);
end;

class procedure TdYdX.Balance(
  client  : TWeb3;
  owner   : TAddress;
  reserve : TReserve;
  callback: TAsyncQuantity);
var
  dYdX: TSoloMargin;
begin
  dYdX := TSoloMargin.Create(client);
  if Assigned(dYdX) then
  try
    dYdX.GetAccountWei(owner, TSoloMargin.marketId[reserve], callback);
  finally
    dYdX.Free;
  end;
end;

class procedure TdYdX.Withdraw(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  callback: TAsyncReceiptEx);
begin
  from.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, 0, err)
    else
      Balance(client, addr, reserve, procedure(amount: BigInteger; err: IError)
      begin
        if Assigned(err) then
          callback(nil, 0, err)
        else
          WithdrawEx(client, from, reserve, amount, callback);
      end);
  end);
end;

class procedure TdYdX.WithdrawEx(
  client  : TWeb3;
  from    : TPrivateKey;
  reserve : TReserve;
  amount  : BigInteger;
  callback: TAsyncReceiptEx);
var
  dYdX: TSoloMargin;
begin
  dYdX := TSoloMargin.Create(client);
  if Assigned(dYdX) then
  try
    dYdX.Withdraw(from, TSoloMargin.marketId[reserve], amount, procedure(rcpt: ITxReceipt; err: IError)
    begin
      if Assigned(err) then
        callback(nil, 0, err)
      else
        callback(rcpt, amount, err);
    end);
  finally
    dYdX.Free;
  end;
end;

{ TSoloMarket }

type
  TSoloMarket = class(TInterfacedObject, ISoloMarket)
  private
    FTuple: TTuple;
  public
    function Token         : TAddress;
    function TotalPar      : TSoloTotalPar;
    function Index         : TSoloIndex;
    function PriceOracle   : TAddress;
    function InterestSetter: TAddress;
    function MarginPremium : Extended;
    function SpreadPremium : Extended;
    function IsClosing     : Boolean;
    constructor Create(aTuple: TTuple);
  end;

constructor TSoloMarket.Create(aTuple: TTuple);
begin
  inherited Create;
  FTuple := aTuple;
end;

function TSoloMarket.Token: TAddress;
begin
  Result := TAddress.New(FTuple[0]);
end;

function TSoloMarket.TotalPar: TSoloTotalPar;
begin
  Result.Borrow := FTuple[1].toBigInt;
  Result.Supply := FTuple[2].toBigInt;
end;

function TSoloMarket.Index: TSoloIndex;
begin
  Result.Borrow     := FTuple[3].toInt64 / INTEREST_RATE_BASE;
  Result.Supply     := FTuple[4].toInt64 / INTEREST_RATE_BASE;
  Result.LastUpdate := FTuple[5].toBigInt;
end;

function TSoloMarket.PriceOracle: TAddress;
begin
  Result := TAddress.New(FTuple[6]);
end;

function TSoloMarket.InterestSetter: TAddress;
begin
  Result := TAddress.New(FTuple[7]);
end;

function TSoloMarket.MarginPremium: Extended;
begin
  Result := FTuple[8].toInt64 / INTEREST_RATE_BASE;
end;

function TSoloMarket.SpreadPremium: Extended;
begin
  Result := FTuple[9].toInt64 / INTEREST_RATE_BASE;
end;

function TSoloMarket.IsClosing: Boolean;
begin
  Result := FTuple[10].toBool;
end;

{ TSoloMargin }

constructor TSoloMargin.Create(aClient: TWeb3);
var
  addr: TAddress;
begin
  addr := TSoloMargin.deployed[aClient.Chain];
  if addr.IsZero then
    raise EdYdx.CreateFmt('dYdX is not deployed on %s',
          [GetEnumName(TypeInfo(TChain), Integer(aClient.Chain))]);
  inherited Create(aClient, addr);
end;

class function TSoloMargin.ToBigInt(value: TTuple): BigInteger;
begin
  if Length(value) < 2 then
    raise EdYdX.Create('not a valid dYdX integer value');
  Result := value[1].toBigInt;
  if (not Result.IsZero) and (not value[0].toBool) then
    Result.Sign := -1;
end;

// Get the token balance for a particular account and market.
procedure TSoloMargin.GetAccountWei(
  owner   : TAddress;
  marketId: Integer;
  callback: TAsyncQuantity);
begin
  web3.eth.call(Client, Contract,
    'getAccountWei((address,uint256),uint256)', [tuple([owner, 0]), marketId],
    procedure(tup: TTuple; err: IError)
    begin
      if Assigned(err) then
        callback(BigInteger.Zero, err)
      else
        callback(TSoloMargin.ToBigInt(tup), err);
    end
  );
end;

// Get the global earnings-rate variable that determines what percentage of the
// interest paid by borrowers gets passed-on to suppliers.
procedure TSoloMargin.GetEarningsRate(callback: TAsyncFloat);
begin
  web3.eth.call(Client, Contract, 'getEarningsRate()', [], procedure(rate: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(rate.AsInt64 / INTEREST_RATE_BASE, nil);
  end);
end;

// Get basic information about a particular market.
procedure TSoloMargin.GetMarket(marketId: Integer; callback: TAsyncSoloMarket);
begin
  web3.eth.call(Client, Contract, 'getMarket(uint256)', [marketId], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      callback(TSoloMarket.Create(tup), err);
  end);
end;

// Get the current borrower interest rate for a market.
procedure TSoloMargin.GetMarketInterestRate(marketId: Integer; callback: TAsyncFloat);
begin
  web3.eth.call(Client, Contract, 'getMarketInterestRate(uint256)', [marketId], procedure(rate: BigInteger; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      callback(rate.AsInt64 / INTEREST_RATE_BASE, nil);
  end);
end;

// https://github.com/dydxprotocol/solo/blob/master/src/modules/Getters.ts#L253
procedure TSoloMargin.GetMarketSupplyInterestRate(marketId: Integer; callback: TAsyncFloat);
begin
  GetEarningsRate(procedure(earningsRate: Extended; err: IError)
  begin
    if Assigned(err) then
      callback(0, err)
    else
      GetMarketInterestRate(marketId, procedure(borrowInterestRate: Extended; err: IError)
      begin
        if Assigned(err) then
          callback(0, err)
        else
          GetMarketUtilization(marketId, procedure(utilization: Extended; err: IError)
          begin
            if Assigned(err) then
              callback(0, err)
            else
              callback(borrowInterestRate * earningsRate * utilization, nil);
          end);
      end);
  end);
end;

// https://github.com/dydxprotocol/solo/blob/master/src/modules/Getters.ts#L230
procedure TSoloMargin.GetMarketUtilization(marketId: Integer; callback: TAsyncFloat);
begin
  GetMarket(marketId, procedure(market: ISoloMarket; err: IError)
  var
    totalSupply: Extended;
    totalBorrow: Extended;
  begin
    if Assigned(err) then
      callback(0, err)
    else
    begin
      totalSupply := market.TotalPar.Supply.AsExtended * market.Index.Supply;
      totalBorrow := market.TotalPar.Borrow.AsExtended * market.Index.Borrow;
      callback(totalBorrow / totalSupply, nil);
    end;
  end);
end;

// The main entry-point to Solo that allows users and contracts to manage accounts.
procedure TSoloMargin.Operate(
  owner            : TPrivateKey;
  actionType       : TSoloActionType;
  amount           : BigInteger;
  denomination     : TSoloDenomination;
  reference        : TSoloReference;
  primaryMarketId  : Integer;
  secondaryMarketId: Integer;
  otherAddress     : TAddress;
  otherAccountId   : Integer;
  callback         : TAsyncReceipt);
begin
  owner.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(Client, owner, Contract,
        'operate(' +
          '(address,uint256)[],' +           // accountOwner, accountNumber
          '(' +
            'uint8,uint256,' +               // actionType, accountId
            '(bool,uint8,uint8,uint256),' +  // sign, denomination, reference, value
            'uint256,' +                     // primaryMarketId
            'uint256,' +                     // secondaryMarketId
            'address,' +                     // otherAddress
            'uint256,' +                     // otherAccountId
            'bytes' +                        // arbitrary data
          ')[]' +
        ')',
        [
          &array([tuple([addr, 0])]),        // accountOwner, accountNumber
          &array([tuple([actionType, 0,      // actionType, accountId
            tuple([
              not(amount.Negative),          // sign
              denomination,                  // denomination
              reference,                     // reference
              web3.utils.toHex(amount.Abs)   // value
            ]),
            primaryMarketId,
            secondaryMarketId,
            otherAddress,
            otherAccountId,
            ''
          ])])
        ],
        callback
      );
  end);
end;

// Moves tokens from an address to Solo.
// Can either repay a borrow or provide additional supply.
procedure TSoloMargin.Deposit(
  owner   : TPrivateKey;
  marketId: Integer;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  owner.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      Operate(
        owner,                    // owner
        TSoloActionType.Deposit,  // actionType
        amount,                   // amount
        TSoloDenomination.Wei,    // denomination
        TSoloReference.Delta,     // reference
        marketId,                 // primaryMarketId
        0,                        // secondaryMarketId (ignored)
        addr,                     // otherAddress
        0,                        // otherAccountId (ignored)
        callback);
  end);
end;

// Moves tokens from Solo to another address.
// Can either borrow tokens or reduce the amount previously supplied.
procedure TSoloMargin.Withdraw(
  owner   : TPrivateKey;
  marketId: Integer;
  amount  : BigInteger;
  callback: TAsyncReceipt);
begin
  if not(amount.IsZero) then
    amount.Sign := -1;
  owner.Address(procedure(addr: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      Operate(
        owner,                     // owner
        TSoloActionType.Withdraw,  // actionType
        amount,                    // amount
        TSoloDenomination.Wei,     // denomination
        TSoloReference.Delta,      // reference
        marketId,                  // primaryMarketId
        0,                         // secondaryMarketId (ignored)
        addr,                      // otherAddress
        0,                         // otherAccountId (ignored)
        callback);
  end);
end;

end.
