{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.erc1155;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth.contract,
  web3.eth.logs,
  web3.eth.types;

type
  // https://eips.ethereum.org/EIPS/eip-1155
  IERC1155 = interface
    // Transfers `value` amount of an `id` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeTransferFrom(
      const owner   : TPrivateKey; // Source address
      const &to     : TAddress;    // Target address
      const id      : BigInteger;  // ID of the token type
      const value   : BigInteger;  // Transfer amount
      const callback: TProc<TTxHash, IError>);
    procedure SafeTransferFromEx(
      const owner   : TPrivateKey; // Source address
      const &to     : TAddress;    // Target address
      const id      : BigInteger;  // ID of the token type
      const value   : BigInteger;  // Transfer amount
      const callback: TProc<ITxReceipt, IError>);
    // Transfers `values` amount(s) of `IDs` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeBatchTransferFrom(
      const owner   : TPrivateKey;         // Source address
      const &to     : TAddress;            // Target address
      const IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      const values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      const callback: TProc<TTxHash, IError>);
    procedure SafeBatchTransferFromEx(
      const owner   : TPrivateKey;         // Source address
      const &to     : TAddress;            // Target address
      const IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      const values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      const callback: TProc<ITxReceipt, IError>);
    // Get the balance of an account's tokens.
    procedure BalanceOf(
      const owner   : TAddress;                   // The address of the token holder
      const id      : BigInteger;                 // ID of the token
      const callback: TProc<BigInteger, IError>); // The owner's balance of the token type requested
    // Get the balance of multiple account/token pairs
    procedure BalanceOfBatch(
      const owners  : array of TAddress;      // The addresses of the token holders
      const IDs     : array of BigInteger;    // IDs of the tokens
      const callback: TProc<TTuple, IError>); // The owner's balance of the token types requested i.e. balance for each (owner, id) pair
    // Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
    procedure SetApprovalForAll(
      const owner    : TPrivateKey; // The token holder
      const &operator: TAddress;    // Address to add to the set of authorized operators
      const approved : Boolean;     // True if the operator is approved, False to revoke approval
      const callback : TProc<ITxReceipt, IError>);
    // Queries the approval status of an operator for a given owner.
    procedure IsApprovedForAll(
      const owner    : TAddress;                // The owner of the tokens
      const &operator: TAddress;                // Address of authorized operator
      const callback : TProc<Boolean, IError>); // True if the operator is approved, False if not
  end;

  IERC1155TokenReceiver = interface
    // Handle the receipt of a single ERC1155 token type.
    procedure OnERC1155Received(
      const &operator: TAddress;                 // The address which initiated the transfer (i.e. msg.sender)
      const from     : TAddress;                 // The address which previously owned the token
      const id       : BigInteger;               // The ID of the token being transferred
      const value    : BigInteger;               // The amount of tokens being transferred
      const callback : TProc<TBytes32, IError>); // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    // Handle the receipt of multiple ERC1155 token types.
    procedure OnERC1155BatchReceived(
      const &operator: TAddress;                 // The address which initiated the batch transfer (i.e. msg.sender)
      const from     : TAddress;                 // The address which previously owned the token
      const IDs      : array of BigInteger;      // An array containing ids of each token being transferred (order and length must match _values array)
      const values   : array of BigInteger;      // An array containing amounts of each token being transferred (order and length must match _ids array)
      const callback : TProc<TBytes32, IError>); // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
  end;

  IERC1155Metadata_URI = interface
    // A distinct Uniform Resource Identifier (URI) for a given token.
    procedure URI(
      const id      : BigInteger;             // ID of the token
      const callback: TProc<string, IError>); // points to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema"
  end;

  // Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
  TOnTransferSingle = reference to procedure(
    Sender   : TObject;
    &Operator: TAddress;    // the address of an account/contract that is approved to make the transfer
    From     : TAddress;    // the address of the holder whose balance is decreased.
    &To      : TAddress;    // the address of the recipient whose balance is increased.
    Id       : BigInteger;  // the token type being transferred.
    Value    : BigInteger); // the number of tokens the holder balance is decreased by and match what the recipient balance is increased by.

  // Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all transfers.
  TOnTransferBatch = reference to procedure(
    Sender   : TObject;
    &Operator: TAddress;             // the address of an account/contract that is approved to make the transfer
    From     : TAddress;             // the address of the holder whose balance is decreased.
    &To      : TAddress;             // the address of the recipient whose balance is increased.
    IDs      : array of BigInteger;  // the list of tokens being transferred.
    Values   : array of BigInteger); // the list of number of tokens (matching the list and order of tokens specified in _ids) the holder balance is decreased by and match what the recipient balance is increased by.

  // Emitted when `owner` grants or revokes permission to `operator` to transfer their tokens, according to `approved`.
  TOnApprovalForAll = reference to procedure(
    Sender   : TObject;
    Owner    : TAddress;
    &Operator: TAddress;
    Approved : Boolean);

  TERC1155 = class(TCustomContract, IERC1155, IERC1155TokenReceiver, IERC1155Metadata_URI)
  strict private
    FLogger: ILogger;
    FOnTransferSingle: TOnTransferSingle;
    FOnTransferBatch : TOnTransferBatch;
    FOnApprovalForAll: TOnApprovalForAll;
    procedure SetOnTransferSingle(const Value: TOnTransferSingle);
    procedure SetOnTransferBatch(const Value: TOnTransferBatch);
    procedure SetOnApprovalForAll(const Value: TOnApprovalForAll);
  protected
    procedure WatchOrStop; virtual;
  public
    constructor Create(const aClient: IWeb3; const aContract: TAddress); override;
    destructor  Destroy; override;
    // Transfers `value` amount of an `id` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeTransferFrom(
      const owner   : TPrivateKey; // Source address
      const &to     : TAddress;    // Target address
      const id      : BigInteger;  // ID of the token type
      const value   : BigInteger;  // Transfer amount
      const callback: TProc<TTxHash, IError>);
    procedure SafeTransferFromEx(
      const owner   : TPrivateKey; // Source address
      const &to     : TAddress;    // Target address
      const id      : BigInteger;  // ID of the token type
      const value   : BigInteger;  // Transfer amount
      const callback: TProc<ITxReceipt, IError>);
    // Transfers `values` amount(s) of `IDs` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeBatchTransferFrom(
      const owner   : TPrivateKey;         // Source address
      const &to     : TAddress;            // Target address
      const IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      const values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      const callback: TProc<TTxHash, IError>);
    procedure SafeBatchTransferFromEx(
      const owner   : TPrivateKey;         // Source address
      const &to     : TAddress;            // Target address
      const IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      const values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      const callback: TProc<ITxReceipt, IError>);
    // Get the balance of an account's tokens.
    procedure BalanceOf(
      const owner   : TAddress;                   // The address of the token holder
      const id      : BigInteger;                 // ID of the token
      const callback: TProc<BigInteger, IError>); // The owner's balance of the token type requested
    // Get the balance of multiple account/token pairs
    procedure BalanceOfBatch(
      const owners  : array of TAddress;      // The addresses of the token holders
      const IDs     : array of BigInteger;    // IDs of the tokens
      const callback: TProc<TTuple, IError>); // The owner's balance of the token types requested i.e. balance for each (owner, id) pair
    // Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
    procedure SetApprovalForAll(
      const owner    : TPrivateKey; // The token holder
      const &operator: TAddress;    // Address to add to the set of authorized operators
      const approved : Boolean;     // True if the operator is approved, False to revoke approval
      const callback : TProc<ITxReceipt, IError>);
    // Queries the approval status of an operator for a given owner.
    procedure IsApprovedForAll(
      const owner    : TAddress;                // The owner of the tokens
      const &operator: TAddress;                // Address of authorized operator
      const callback : TProc<Boolean, IError>); // True if the operator is approved, False if not
    // Handle the receipt of a single ERC1155 token type.
    procedure OnERC1155Received(
      const &operator: TAddress;                 // The address which initiated the transfer (i.e. msg.sender)
      const from     : TAddress;                 // The address which previously owned the token
      const id       : BigInteger;               // The ID of the token being transferred
      const value    : BigInteger;               // The amount of tokens being transferred
      const callback : TProc<TBytes32, IError>); // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    // Handle the receipt of multiple ERC1155 token types.
    procedure OnERC1155BatchReceived(
      const &operator: TAddress;                 // The address which initiated the batch transfer (i.e. msg.sender)
      const from     : TAddress;                 // The address which previously owned the token
      const IDs      : array of BigInteger;      // An array containing ids of each token being transferred (order and length must match _values array)
      const values   : array of BigInteger;      // An array containing amounts of each token being transferred (order and length must match _ids array)
      const callback : TProc<TBytes32, IError>); // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
    // A distinct Uniform Resource Identifier (URI) for a given token.
    procedure URI(
      const id      : BigInteger;             // ID of the token
      const callback: TProc<string, IError>); // points to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema"
    // events
    property OnTransferSingle: TOnTransferSingle read FOnTransferSingle write SetOnTransferSingle;
    property OnTransferBatch : TOnTransferBatch  read FOnTransferBatch  write SetOnTransferBatch;
    property OnApprovalForAll: TOnApprovalForAll read FOnApprovalForAll write SetOnApprovalForAll;
  end;

implementation

uses
  // web3
  web3.eth,
  web3.eth.abi,
  web3.utils;

{ TERC1155}

constructor TERC1155.Create(const aClient: IWeb3; const aContract: TAddress);
begin
  inherited Create(aClient, aContract);

  FLogger := web3.eth.logs.get(aClient, aContract,
    procedure(log: PLog; err: IError)
    begin
      if not Assigned(log) then
        EXIT;

      if Assigned(FOnTransferSingle) then
        if log^.isEvent('TransferSingle(address,address,address,uint256,uint256)') then
          FOnTransferSingle(Self,
            log^.Topic[1].toAddress, // operator
            log^.Topic[2].toAddress, // from
            log^.Topic[3].toAddress, // to
            log^.Data[0].toUInt256,  // id
            log^.Data[1].toUInt256   // value
          );

      if Assigned(FOnTransferBatch) then
        if log^.isEvent('TransferBatch(address,address,address,uint256[],uint256[])') then
          FOnTransferBatch(Self,
            log^.Topic[1].toAddress, // operator
            log^.Topic[2].toAddress, // from
            log^.Topic[3].toAddress, // to
            [],                      // IDs
            []                       // values
          );

      if Assigned(FOnApprovalForAll) then
        if log^.isEvent('ApprovalForAll(address,address,bool)') then
          FOnApprovalForAll(Self,
            log^.Topic[1].toAddress, // owner
            log^.Topic[2].toAddress, // operator
            log^.Data[0].toBoolean   // approved
          );
    end);
end;

destructor TERC1155.Destroy;
begin
  if FLogger.Status in [Running, Paused] then FLogger.Stop;
  inherited Destroy;
end;

procedure TERC1155.SetOnTransferSingle(const Value: TOnTransferSingle);
begin
  FOnTransferSingle := Value;
  WatchOrStop;
end;

procedure TERC1155.SetOnTransferBatch(const Value: TOnTransferBatch);
begin
  FOnTransferBatch := Value;
  WatchOrStop;
end;

procedure TERC1155.SetOnApprovalForAll(const Value: TOnApprovalForAll);
begin
  FOnApprovalForAll := Value;
  WatchOrStop;
end;

procedure TERC1155.WatchOrStop;
begin
  if Assigned(FOnTransferSingle) or Assigned(FOnTransferBatch) or Assigned(FOnApprovalForAll) then
  begin
    if FLogger.Status in [Idle, Paused] then FLogger.Start;
    EXIT;
  end;
  if FLogger.Status = Running then FLogger.Pause;
end;

// Transfers `value` amount of an `id` from the `owner` address to the `to` address specified (with safety call).
procedure TERC1155.SafeTransferFrom(
  const owner   : TPrivateKey; // Source address
  const &to     : TAddress;    // Target address
  const id      : BigInteger;  // ID of the token type
  const value   : BigInteger;  // Transfer amount
  const callback: TProc<TTxHash, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback('', err)
    end)
    .&else(procedure(from: TAddress)
    begin
      web3.eth.write(Self.Client, owner, Self.Contract, 'safeTransferFrom(address,address,uint256,uint256,bytes)', [from, &to, web3.utils.toHex(id), web3.utils.toHex(value), ''], callback)
    end);
end;

procedure TERC1155.SafeTransferFromEx(
  const owner   : TPrivateKey; // Source address
  const &to     : TAddress;    // Target address
  const id      : BigInteger;  // ID of the token type
  const value   : BigInteger;  // Transfer amount
  const callback: TProc<ITxReceipt, IError>);
begin
  owner.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(from: TAddress)
    begin
      web3.eth.write(Self.Client, owner, Self.Contract, 'safeTransferFrom(address,address,uint256,uint256,bytes)', [from, &to, web3.utils.toHex(id), web3.utils.toHex(value), ''], callback)
    end);
end;

// Transfers `values` amount(s) of `IDs` from the `owner` address to the `to` address specified (with safety call).
procedure TERC1155.SafeBatchTransferFrom(
  const owner   : TPrivateKey;         // Source address
  const &to     : TAddress;            // Target address
  const IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
  const values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
  const callback: TProc<TTxHash, IError>);
begin
  const from = owner.GetAddress;
  if from.isErr then
    callback('', from.Error)
  else
    web3.eth.write(Self.Client, owner, Self.Contract, 'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)', [from.Value, &to, &array(IDs), &array(values), ''], callback)
end;

procedure TERC1155.SafeBatchTransferFromEx(
  const owner   : TPrivateKey;         // Source address
  const &to     : TAddress;            // Target address
  const IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
  const values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
  const callback: TProc<ITxReceipt, IError>);
begin
  const from = owner.GetAddress;
  if from.isErr then
    callback(nil, from.Error)
  else
    web3.eth.write(Self.Client, owner, Self.Contract, 'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)', [from.Value, &to, &array(IDs), &array(values), ''], callback)
end;

// Get the balance of an account's tokens.
procedure TERC1155.BalanceOf(
  const owner   : TAddress;                   // The address of the token holder
  const id      : BigInteger;                 // ID of the token
  const callback: TProc<BigInteger, IError>); // The owner's balance of the token type requested
begin
  web3.eth.call(Self.Client, Self.Contract, 'balanceOf(address,uint256)', [owner, web3.utils.toHex(id)], callback)
end;

// Get the balance of multiple account/token pairs
procedure TERC1155.BalanceOfBatch(
  const owners  : array of TAddress;      // The addresses of the token holders
  const IDs     : array of BigInteger;    // IDs of the tokens
  const callback: TProc<TTuple, IError>); // The owner's balance of the token types requested i.e. balance for each (owner, id) pair
begin
  web3.eth.call(Self.Client, Self.Contract, 'balanceOfBatch(address[],uint256[])', [&array(owners), &array(ids)], callback)
end;

// Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
procedure TERC1155.SetApprovalForAll(
  const owner    : TPrivateKey; // The token holder
  const &operator: TAddress;    // Address to add to the set of authorized operators
  const approved : Boolean;     // True if the operator is approved, False to revoke approval
  const callback : TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Self.Client, owner, Self.Contract, 'setApprovalForAll(address,bool)', [&operator, approved], callback)
end;

// Queries the approval status of an operator for a given owner.
procedure TERC1155.IsApprovedForAll(
  const owner    : TAddress;                // The owner of the tokens
  const &operator: TAddress;                // Address of authorized operator
  const callback : TProc<Boolean, IError>); // True if the operator is approved, False if not
begin
  web3.eth.call(Self.Client, Self.Contract, 'isApprovedForAll(address,address)', [owner, &operator], callback)
end;

// Handle the receipt of a single ERC1155 token type.
procedure TERC1155.OnERC1155Received(
  const &operator: TAddress;                 // The address which initiated the transfer (i.e. msg.sender)
  const from     : TAddress;                 // The address which previously owned the token
  const id       : BigInteger;               // The ID of the token being transferred
  const value    : BigInteger;               // The amount of tokens being transferred
  const callback : TProc<TBytes32, IError>); // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
begin
  web3.eth.call(Self.Client, Self.Contract, 'onERC1155Received(address,address,uint256,uint256,bytes)', [&operator, from, web3.utils.toHex(id), web3.utils.toHex(value), ''], callback)
end;

// Handle the receipt of multiple ERC1155 token types.
procedure TERC1155.OnERC1155BatchReceived(
  const &operator: TAddress;                 // The address which initiated the batch transfer (i.e. msg.sender)
  const from     : TAddress;                 // The address which previously owned the token
  const IDs      : array of BigInteger;      // An array containing ids of each token being transferred (order and length must match _values array)
  const values   : array of BigInteger;      // An array containing amounts of each token being transferred (order and length must match _ids array)
  const callback : TProc<TBytes32, IError>); // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
begin
  web3.eth.call(Self.Client, Self.Contract, 'onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)', [&operator, from, &array(IDs), &array(values), ''], callback)
end;

// A distinct Uniform Resource Identifier (URI) for a given token.
procedure TERC1155.URI(
  const id      : BigInteger;             // ID of the token
  const callback: TProc<string, IError>); // points to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema"
begin
  web3.eth.call(Self.Client, Self.Contract, 'uri(uint256)', [web3.utils.toHex(id)], callback)
end;

end.
