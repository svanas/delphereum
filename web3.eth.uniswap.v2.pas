{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2020 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.uniswap.v2;

{$I web3.inc}

interface

uses
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // Delphi
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  // web3
  web3,
  web3.eth,
  web3.eth.abi,
  web3.eth.contract,
  web3.eth.erc20,
  web3.eth.gas,
  web3.eth.types,
  web3.eth.utils,
  web3.graph,
  web3.json,
  web3.utils;

type
  TFactory = class(TCustomContract)
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure GetPair(tokenA, tokenB: TAddress; callback: TProc<TAddress, IError>);
  end;

  TRouter02 = class(TCustomContract)
  private
    procedure SwapExactTokensForETH(
      from        : TPrivateKey;   // Sender of the token.
      amountIn    : BigInteger;    // The amount of input tokens to send.
      amountOutMin: BigInteger;    // The minimum amount of output tokens that must be received for the transaction not to revert.
      token0      : TAddress;      // The address of the pair token with the lower sort order.
      token1      : TAddress;      // The address of the pair token with the higher sort order.
      &to         : TAddress;      // Recipient of the ETH.
      deadline    : TUnixDateTime; // Unix timestamp after which the transaction will revert.
      callback    : TProc<ITxReceipt, IError>); overload;
    procedure SwapExactETHForTokens(
      from        : TPrivateKey;   // Sender of ETH.
      amountIn    : BigInteger;    // The amount of ETH to send.
      amountOutMin: BigInteger;    // The minimum amount of output tokens that must be received for the transaction not to revert.
      token       : TAddress;      // The token address.
      &to         : TAddress;      // Recipient of the output tokens.
      deadline    : TUnixDateTime; // Unix timestamp after which the transaction will revert.
      callback    : TProc<ITxReceipt, IError>); overload;
  public
    constructor Create(aClient: IWeb3); reintroduce;
    procedure WETH(callback: TProc<TAddress, IError>);
    procedure SwapExactTokensForETH(
      owner       : TPrivateKey; // Sender of the token, and recipient of the ETH.
      amountIn    : BigInteger;  // The amount of input tokens to send.
      amountOutMin: BigInteger;  // The minimum amount of output tokens that must be received for the transaction not to revert.
      token       : TAddress;    // The address of the token you wish to swap.
      minutes     : Int64;       // Your transaction will revert if it is pending for more than this long.
      callback    : TProc<ITxReceipt, IError>); overload;
    procedure SwapExactETHForTokens(
      owner       : TPrivateKey; // Sender of ETH.
      amountIn    : BigInteger;  // The amount of ETH to send.
      amountOutMin: BigInteger;  // The minimum amount of output tokens that must be received for the transaction not to revert.
      token       : TAddress;    // The token address.
      minutes     : Int64;       // Your transaction will revert if it is pending for more than this long.
      callback    : TProc<ITxReceipt, IError>); overload;
  end;

  TPair = class(TERC20)
  protected
    function  Query  (const field: string): string;
    procedure Execute(const field: string; callback: TProc<Double, IError>);
  public
    procedure Token0(callback: TProc<TAddress, IError>);
    procedure Token1(callback: TProc<TAddress, IError>);
    procedure Token0Price(callback: TProc<Double, IError>);
    procedure Token1Price(callback: TProc<Double, IError>);
  end;

implementation

{ TFactory }

constructor TFactory.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f');
end;

// Returns the address of the pair for tokenA and tokenB, if it has been created, else 0x0
procedure TFactory.GetPair(tokenA, tokenB: TAddress; callback: TProc<TAddress, IError>);
begin
  call(Client, Contract, 'getPair(address,address)', [tokenA, tokenB], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(EMPTY_ADDRESS, err);
      EXIT;
    end;
    const pair = TAddress.Create(hex);
    if pair.IsZero then
    begin
      callback(EMPTY_ADDRESS, TError.Create('%s does not exist', [tokenA]));
      EXIT;
    end;
    callback(pair, nil)
  end);
end;

{ TRouter02 }

constructor TRouter02.Create(aClient: IWeb3);
begin
  inherited Create(aClient, '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D');
end;

// Returns the canonical WETH address; see https://blog.0xproject.com/canonical-weth-a9aa7d0279dd
procedure TRouter02.WETH(callback: TProc<TAddress, IError>);
begin
  call(Client, Contract, 'WETH()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// Swaps an exact amount of tokens for as much ETH as possible.
procedure TRouter02.SwapExactTokensForETH(
  from        : TPrivateKey;   // Sender of the token.
  amountIn    : BigInteger;    // The amount of input tokens to send.
  amountOutMin: BigInteger;    // The minimum amount of output tokens that must be received for the transaction not to revert.
  token0      : TAddress;      // The address of the pair token with the lower sort order.
  token1      : TAddress;      // The address of the pair token with the higher sort order.
  &to         : TAddress;      // Recipient of the ETH.
  deadline    : TUnixDateTime; // Unix timestamp after which the transaction will revert.
  callback    : TProc<ITxReceipt, IError>);
begin
  web3.eth.erc20.approve(web3.eth.erc20.create(Self.Client, token0), from, Self.Contract, amountIn, procedure(rcpt: ITxReceipt; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(Client, from, Contract,
        'swapExactTokensForETH(uint256,uint256,address[],address,uint256)',
        [
          web3.utils.toHex(amountIn),
          web3.utils.toHex(amountOutMin),
          &array([token0, token1]),
          &to,
          deadline
        ], callback);
  end);
end;

procedure TRouter02.SwapExactETHForTokens(
  from        : TPrivateKey;   // Sender of ETH.
  amountIn    : BigInteger;    // The amount of ETH to send.
  amountOutMin: BigInteger;    // The minimum amount of output tokens that must be received for the transaction not to revert.
  token       : TAddress;      // The token address.
  &to         : TAddress;      // Recipient of the output tokens.
  deadline    : TUnixDateTime; // Unix timestamp after which the transaction will revert.
  callback    : TProc<ITxReceipt, IError>);
begin
  Self.WETH(procedure(WETH: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(Client, from, Contract, amountIn,
        'swapExactETHForTokens(uint256,address[],address,uint256)',
        [
          web3.utils.toHex(amountOutMin),
          &array([WETH, token]),
          &to,
          deadline
        ], callback);
  end);
end;

// Swaps an exact amount of tokens for as much ETH as possible.
procedure TRouter02.SwapExactTokensForETH(
  owner       : TPrivateKey; // Sender of the token, and recipient of the ETH.
  amountIn    : BigInteger;  // The amount of input tokens to send.
  amountOutMin: BigInteger;  // The minimum amount of output tokens that must be received for the transaction not to revert.
  token       : TAddress;    // The address of the token you wish to swap.
  minutes     : Int64;       // Your transaction will revert if it is pending for more than this long.
  callback    : TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(receiver: TAddress)
    begin
      Self.WETH(procedure(WETH: TAddress; err: IError)
      begin
        if Assigned(err) then
          callback(nil, err)
        else
          Self.SwapExactTokensForETH(
            owner,
            amountIn,
            amountOutMin,
            token,
            WETH,
            receiver,
            DateTimeToUnix(IncMinute(System.SysUtils.Now, minutes), False),
            callback
          )
      end);
    end);
end;

procedure TRouter02.SwapExactETHForTokens(
  owner       : TPrivateKey; // Sender of ETH.
  amountIn    : BigInteger;  // The amount of ETH to send.
  amountOutMin: BigInteger;  // The minimum amount of output tokens that must be received for the transaction not to revert.
  token       : TAddress;    // The token address.
  minutes     : Int64;       // Your transaction will revert if it is pending for more than this long.
  callback    : TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(receiver: TAddress)
    begin
      Self.SwapExactETHForTokens(
        owner,
        amountIn,
        amountOutMin,
        token,
        receiver,
        DateTimeToUnix(IncMinute(System.SysUtils.Now, minutes), False),
        callback
      )
    end);
end;

{ TPair }

// Returns the address of the pair token with the lower sort order.
procedure TPair.Token0(callback: TProc<TAddress, IError>);
begin
  call(Client, Contract, 'token0()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// Returns the address of the pair token with the higher sort order.
procedure TPair.Token1(callback: TProc<TAddress, IError>);
begin
  call(Client, Contract, 'token1()', [], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(EMPTY_ADDRESS, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

// Returns a GraphQL query; see https://uniswap.org/docs/v2/API/entities/#pair
function TPair.Query(const field: string): string;
begin
  Result := Format('{"query":"{pair(id:\"%s\"){%s}}"}', [string(Contract).ToLower, field]);
end;

// Execute a GraphQL query, return the result as a float (if any)
procedure TPair.Execute(const field: string; callback: TProc<Double, IError>);
begin
  web3.graph.execute('https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v2', Query(field), procedure(response: TJsonObject; err: IError)
  begin
    if Assigned(err) then
    begin
      callback(0, err);
      EXIT;
    end;
    const data = web3.json.getPropAsObj(response, 'data');
    if Assigned(data) then
    begin
      const pair = web3.json.getPropAsObj(data, 'pair');
      if Assigned(pair) then
      begin
        callback(DotToFloat(web3.json.getPropAsStr(pair, field)), nil);
        EXIT;
      end;
    end;
    callback(0, TGraphError.Create('an unknown error occurred'));
  end);
end;

// Token0 per Token1
procedure TPair.Token0Price(callback: TProc<Double, IError>);
begin
  Execute('token0Price', callback);
end;

// Token1 per Token0
procedure TPair.Token1Price(callback: TProc<Double, IError>);
begin
  Execute('token1Price', callback);
end;

end.
