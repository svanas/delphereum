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
      owner   : TPrivateKey; // Source address
      &to     : TAddress;    // Target address
      id      : BigInteger;  // ID of the token type
      value   : BigInteger;  // Transfer amount
      callback: TAsyncTxHash);
    procedure SafeTransferFromEx(
      owner   : TPrivateKey; // Source address
      &to     : TAddress;    // Target address
      id      : BigInteger;  // ID of the token type
      value   : BigInteger;  // Transfer amount
      callback: TAsyncReceipt);
    // Transfers `values` amount(s) of `IDs` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeBatchTransferFrom(
      owner   : TPrivateKey;         // Source address
      &to     : TAddress;            // Target address
      IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      callback: TAsyncTxHash);
    procedure SafeBatchTransferFromEx(
      owner   : TPrivateKey;         // Source address
      &to     : TAddress;            // Target address
      IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      callback: TAsyncReceipt);
    // Get the balance of an account's tokens.
    procedure BalanceOf(
      owner   : TAddress;        // The address of the token holder
      id      : BigInteger;      // ID of the token
      callback: TAsyncQuantity); // The owner's balance of the token type requested
    // Get the balance of multiple account/token pairs
    procedure BalanceOfBatch(
      owners  : array of TAddress;   // The addresses of the token holders
      IDs     : array of BigInteger; // IDs of the tokens
      callback: TAsyncTuple);        // The owner's balance of the token types requested i.e. balance for each (owner, id) pair
    // Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
    procedure SetApprovalForAll(
      owner    : TPrivateKey; // The token holder
      &operator: TAddress;    // Address to add to the set of authorized operators
      approved : Boolean;     // True if the operator is approved, False to revoke approval
      callback : TAsyncReceipt);
    // Queries the approval status of an operator for a given owner.
    procedure IsApprovedForAll(
      owner    : TAddress;       // The owner of the tokens
      &operator: TAddress;       // Address of authorized operator
      callback : TAsyncBoolean); // True if the operator is approved, False if not
  end;

  IERC1155TokenReceiver = interface
    // Handle the receipt of a single ERC1155 token type.
    procedure OnERC1155Received(
      &operator: TAddress;       // The address which initiated the transfer (i.e. msg.sender)
      from     : TAddress;       // The address which previously owned the token
      id       : BigInteger;     // The ID of the token being transferred
      value    : BigInteger;     // The amount of tokens being transferred
      callback : TAsyncBytes32); // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    // Handle the receipt of multiple ERC1155 token types.
    procedure OnERC1155BatchReceived(
      &operator: TAddress;            // The address which initiated the batch transfer (i.e. msg.sender)
      from     : TAddress;            // The address which previously owned the token
      IDs      : array of BigInteger; // An array containing ids of each token being transferred (order and length must match _values array)
      values   : array of BigInteger; // An array containing amounts of each token being transferred (order and length must match _ids array)
      callback : TAsyncBytes32);      // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
  end;

  IERC1155Metadata_URI = interface
    // A distinct Uniform Resource Identifier (URI) for a given token.
    procedure URI(
      id      : BigInteger;    // ID of the token
      callback: TAsyncString); // points to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema"
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
    procedure SetOnTransferSingle(Value: TOnTransferSingle);
    procedure SetOnTransferBatch(Value: TOnTransferBatch);
    procedure SetOnApprovalForAll(Value: TOnApprovalForAll);
  protected
    procedure WatchOrStop; virtual;
  public
    constructor Create(aClient: IWeb3; aContract: TAddress); override;
    destructor  Destroy; override;
    // Transfers `value` amount of an `id` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeTransferFrom(
      owner   : TPrivateKey; // Source address
      &to     : TAddress;    // Target address
      id      : BigInteger;  // ID of the token type
      value   : BigInteger;  // Transfer amount
      callback: TAsyncTxHash);
    procedure SafeTransferFromEx(
      owner   : TPrivateKey; // Source address
      &to     : TAddress;    // Target address
      id      : BigInteger;  // ID of the token type
      value   : BigInteger;  // Transfer amount
      callback: TAsyncReceipt);
    // Transfers `values` amount(s) of `IDs` from the `owner` address to the `to` address specified (with safety call).
    procedure SafeBatchTransferFrom(
      owner   : TPrivateKey;         // Source address
      &to     : TAddress;            // Target address
      IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      callback: TAsyncTxHash);
    procedure SafeBatchTransferFromEx(
      owner   : TPrivateKey;         // Source address
      &to     : TAddress;            // Target address
      IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
      values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
      callback: TAsyncReceipt);
    // Get the balance of an account's tokens.
    procedure BalanceOf(
      owner   : TAddress;        // The address of the token holder
      id      : BigInteger;      // ID of the token
      callback: TAsyncQuantity); // The owner's balance of the token type requested
    // Get the balance of multiple account/token pairs
    procedure BalanceOfBatch(
      owners  : array of TAddress;   // The addresses of the token holders
      IDs     : array of BigInteger; // IDs of the tokens
      callback: TAsyncTuple);        // The owner's balance of the token types requested i.e. balance for each (owner, id) pair
    // Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
    procedure SetApprovalForAll(
      owner    : TPrivateKey; // The token holder
      &operator: TAddress;    // Address to add to the set of authorized operators
      approved : Boolean;     // True if the operator is approved, False to revoke approval
      callback : TAsyncReceipt);
    // Queries the approval status of an operator for a given owner.
    procedure IsApprovedForAll(
      owner    : TAddress;       // The owner of the tokens
      &operator: TAddress;       // Address of authorized operator
      callback : TAsyncBoolean); // True if the operator is approved, False if not
    // Handle the receipt of a single ERC1155 token type.
    procedure OnERC1155Received(
      &operator: TAddress;       // The address which initiated the transfer (i.e. msg.sender)
      from     : TAddress;       // The address which previously owned the token
      id       : BigInteger;     // The ID of the token being transferred
      value    : BigInteger;     // The amount of tokens being transferred
      callback : TAsyncBytes32); // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
    // Handle the receipt of multiple ERC1155 token types.
    procedure OnERC1155BatchReceived(
      &operator: TAddress;            // The address which initiated the batch transfer (i.e. msg.sender)
      from     : TAddress;            // The address which previously owned the token
      IDs      : array of BigInteger; // An array containing ids of each token being transferred (order and length must match _values array)
      values   : array of BigInteger; // An array containing amounts of each token being transferred (order and length must match _ids array)
      callback : TAsyncBytes32);      // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
    // A distinct Uniform Resource Identifier (URI) for a given token.
    procedure URI(
      id      : BigInteger;    // ID of the token
      callback: TAsyncString); // points to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema"
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

constructor TERC1155.Create(aClient: IWeb3; aContract: TAddress);
begin
  inherited Create(aClient, aContract);

  FLogger := web3.eth.logs.get(aClient, aContract,
    procedure(log: TLog)
    begin
      if Assigned(FOnTransferSingle) then
        if log.isEvent('TransferSingle(address,address,address,uint256,uint256)') then
          FOnTransferSingle(Self,
            log.Topic[1].toAddress, // operator
            log.Topic[2].toAddress, // from
            log.Topic[3].toAddress, // to
            log.Data[0].toBigInt,   // id
            log.Data[1].toBigInt    // value
          );
      if Assigned(FOnTransferBatch) then
        if log.isEvent('TransferBatch(address,address,address,uint256[],uint256[])') then
          FOnTransferBatch(Self,
            log.Topic[1].toAddress, // operator
            log.Topic[2].toAddress, // from
            log.Topic[3].toAddress, // to
            [],                     // IDs
            []                      // values
          );
      if Assigned(FOnApprovalForAll) then
        if log.isEvent('ApprovalForAll(address,address,bool)') then
          FOnApprovalForAll(Self,
            log.Topic[1].toAddress, // owner
            log.Topic[2].toAddress, // operator
            log.Data[0].toBoolean   // apprpved
          );
    end);
end;

destructor TERC1155.Destroy;
begin
  if FLogger.Status in [Running, Paused] then
    FLogger.Stop;
  inherited Destroy;
end;

procedure TERC1155.SetOnTransferSingle(Value: TOnTransferSingle);
begin
  FOnTransferSingle := Value;
  WatchOrStop;
end;

procedure TERC1155.SetOnTransferBatch(Value: TOnTransferBatch);
begin
  FOnTransferBatch := Value;
  WatchOrStop;
end;

procedure TERC1155.SetOnApprovalForAll(Value: TOnApprovalForAll);
begin
  FOnApprovalForAll := Value;
  WatchOrStop;
end;

procedure TERC1155.WatchOrStop;
begin
  if Assigned(FOnTransferSingle)
  or Assigned(FOnTransferBatch)
  or Assigned(FOnApprovalForAll) then
  begin
    if FLogger.Status in [Idle, Paused] then
      FLogger.Start;
    EXIT;
  end;
  if FLogger.Status = Running then
    FLogger.Pause;
end;

// Transfers `value` amount of an `id` from the `owner` address to the `to` address specified (with safety call).
procedure TERC1155.SafeTransferFrom(
  owner   : TPrivateKey; // Source address
  &to     : TAddress;    // Target address
  id      : BigInteger;  // ID of the token type
  value   : BigInteger;  // Transfer amount
  callback: TAsyncTxHash);
begin
  owner.Address(procedure(from: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.write(
        Self.Client,
        owner,
        Self.Contract,
        'safeTransferFrom(address,address,uint256,uint256,bytes)',
        [from, &to, web3.utils.toHex(id), web3.utils.toHex(value), ''],
        callback
      );
  end);
end;

procedure TERC1155.SafeTransferFromEx(
  owner   : TPrivateKey; // Source address
  &to     : TAddress;    // Target address
  id      : BigInteger;  // ID of the token type
  value   : BigInteger;  // Transfer amount
  callback: TAsyncReceipt);
begin
  owner.Address(procedure(from: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(
        Self.Client,
        owner,
        Self.Contract,
        'safeTransferFrom(address,address,uint256,uint256,bytes)',
        [from, &to, web3.utils.toHex(id), web3.utils.toHex(value), ''],
        callback
      );
  end);
end;

// Transfers `values` amount(s) of `IDs` from the `owner` address to the `to` address specified (with safety call).
procedure TERC1155.SafeBatchTransferFrom(
  owner   : TPrivateKey;         // Source address
  &to     : TAddress;            // Target address
  IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
  values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
  callback: TAsyncTxHash);
begin
  const _IDs    = &array(IDs);
  const _values = &array(values);
  owner.Address(procedure(from: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      web3.eth.write(
        Self.Client,
        owner,
        Self.Contract,
        'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)',
        [from, &to, _IDs, _values, ''],
        callback
      );
  end);
end;

procedure TERC1155.SafeBatchTransferFromEx(
  owner   : TPrivateKey;         // Source address
  &to     : TAddress;            // Target address
  IDs     : array of BigInteger; // IDs of each token type (order and length must match `values` array)
  values  : array of BigInteger; // Transfer amounts per token type (order and length must match `IDs` array)
  callback: TAsyncReceipt);
begin
  const _IDs    = &array(IDs);
  const _values = &array(values);
  owner.Address(procedure(from: TAddress; err: IError)
  begin
    if Assigned(err) then
      callback(nil, err)
    else
      web3.eth.write(
        Self.Client,
        owner,
        Self.Contract,
        'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)',
        [from, &to, _IDs, _values, ''],
        callback
      );
  end);
end;

// Get the balance of an account's tokens.
procedure TERC1155.BalanceOf(
  owner   : TAddress;        // The address of the token holder
  id      : BigInteger;      // ID of the token
  callback: TAsyncQuantity); // The owner's balance of the token type requested
begin
  web3.eth.call(
    Self.Client,
    Self.Contract,
    'balanceOf(address,uint256)',
    [owner, web3.utils.toHex(id)],
    callback
  );
end;

// Get the balance of multiple account/token pairs
procedure TERC1155.BalanceOfBatch(
  owners  : array of TAddress;   // The addresses of the token holders
  IDs     : array of BigInteger; // IDs of the tokens
  callback: TAsyncTuple);        // The owner's balance of the token types requested i.e. balance for each (owner, id) pair
begin
  web3.eth.call(
    Self.Client,
    Self.Contract,
    'balanceOfBatch(address[],uint256[])',
    [&array(owners), &array(ids)],
    callback
  );
end;

// Enable or disable approval for a third party ("operator") to manage all of the caller's tokens.
procedure TERC1155.SetApprovalForAll(
  owner    : TPrivateKey; // The token holder
  &operator: TAddress;    // Address to add to the set of authorized operators
  approved : Boolean;     // True if the operator is approved, False to revoke approval
  callback : TAsyncReceipt);
begin
  web3.eth.write(
    Self.Client,
    owner,
    Self.Contract,
    'setApprovalForAll(address,bool)',
    [&operator, approved],
    callback
  );
end;

// Queries the approval status of an operator for a given owner.
procedure TERC1155.IsApprovedForAll(
  owner    : TAddress;       // The owner of the tokens
  &operator: TAddress;       // Address of authorized operator
  callback : TAsyncBoolean); // True if the operator is approved, False if not
begin
  web3.eth.call(
    Self.Client,
    Self.Contract,
    'isApprovedForAll(address,address)',
    [owner, &operator],
    callback
  );
end;

// Handle the receipt of a single ERC1155 token type.
procedure TERC1155.OnERC1155Received(
  &operator: TAddress;       // The address which initiated the transfer (i.e. msg.sender)
  from     : TAddress;       // The address which previously owned the token
  id       : BigInteger;     // The ID of the token being transferred
  value    : BigInteger;     // The amount of tokens being transferred
  callback : TAsyncBytes32); // bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
begin
  web3.eth.call(
    Self.Client,
    Self.Contract,
    'onERC1155Received(address,address,uint256,uint256,bytes)',
    [&operator, from, web3.utils.toHex(id), web3.utils.toHex(value), ''],
    callback
  );
end;

// Handle the receipt of multiple ERC1155 token types.
procedure TERC1155.OnERC1155BatchReceived(
  &operator: TAddress;            // The address which initiated the batch transfer (i.e. msg.sender)
  from     : TAddress;            // The address which previously owned the token
  IDs      : array of BigInteger; // An array containing ids of each token being transferred (order and length must match _values array)
  values   : array of BigInteger; // An array containing amounts of each token being transferred (order and length must match _ids array)
  callback : TAsyncBytes32);      // bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
begin
  web3.eth.call(
    Self.Client,
    Self.Contract,
    'onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)',
    [&operator, from, &array(IDs), &array(values), ''],
    callback
  );
end;

// A distinct Uniform Resource Identifier (URI) for a given token.
procedure TERC1155.URI(
  id      : BigInteger;    // ID of the token
  callback: TAsyncString); // points to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema"
begin
  web3.eth.call(
    Self.Client,
    Self.Contract,
    'uri(uint256)',
    [web3.utils.toHex(id)],
    callback
  );
end;

end.
