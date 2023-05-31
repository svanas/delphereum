{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.erc721;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers,
  // web3
  web3,
  web3.eth,
  web3.eth.contract,
  web3.eth.crypto,
  web3.eth.logs,
  web3.eth.types,
  web3.utils;

type
  // https://eips.ethereum.org/EIPS/eip-721
  IERC721 = interface
    // Count all NFTs assigned to an owner
    procedure BalanceOf(
      const owner   : TAddress;                   // An address for whom to query the balance
      const callback: TProc<BigInteger, IError>); // The number of NFTs owned by `owner`, possibly zero
    // Find the owner of an NFT
    procedure OwnerOf(
      const tokenId : BigInteger;               // The identifier for an NFT
      const callback: TProc<TAddress, IError>); // The address of the owner of the NFT
    // Transfers the ownership of an NFT from one address to another address
    // Throws...
    // 1) if `from` is not the current owner, or
    // 2) if `to` is the zero address, or
    // 3) if `tokenId` is not a valid NFT, or
    // 4) unless `msg.sender` is the current owner, an authorized operator, or the approved address for this NFT.
    procedure SafeTransferFrom(
      const from    : TPrivateKey;     // The current owner of the NFT
      const &to     : TAddress;        // The new owner
      const tokenId : BigInteger;      // The NFT to transfer
      const callback: TProc<TTxHash, IError>);
    procedure SafeTransferFromEx(
      const from    : TPrivateKey;     // The current owner of the NFT
      const &to     : TAddress;        // The new owner
      const tokenId : BigInteger;      // The NFT to transfer
      const callback: TProc<ITxReceipt, IError>);
    // Transfers the ownership of an NFT from one address to another address
    // THE CALLER IS RESPONSIBLE TO CONFIRM THAT `to` IS CAPABLE OF RECEIVING
    // NFTs OR ELSE THEY MAY BE PERMANENTLY LOST
    procedure TransferFrom(
      const from    : TPrivateKey;     // The current owner of the NFT
      const &to     : TAddress;        // The new owner
      const tokenId : BigInteger;      // The NFT to transfer
      const callback: TProc<TTxHash, IError>);
    procedure TransferFromEx(
      const from    : TPrivateKey;     // The current owner of the NFT
      const &to     : TAddress;        // The new owner
      const tokenId : BigInteger;      // The NFT to transfer
      const callback: TProc<ITxReceipt, IError>);
    // Change or reaffirm the approved address for an NFT
    procedure Approve(
      const owner   : TPrivateKey;     // The current owner of the NFT
      const spender : TAddress;        // The new approved NFT controller
      const tokenId : BigInteger;      // The NFT to approve
      const callback: TProc<ITxReceipt, IError>);
    // Change or reaffirm the approved address for an NFT
    procedure SetApprovalForAll(
      const owner    : TPrivateKey;     // The current owner of the NFT
      const &operator: TAddress;        // Address to add to the set of authorized operators
      const approved : Boolean;         // True if the operator is approved, false to revoke approval
      const callback : TProc<ITxReceipt, IError>);
    // Get the approved address for a single NFT
    procedure GetApproved(
      const tokenId : BigInteger;               // The NFT to find the approved address for
      const callback: TProc<TAddress, IError>); // The approved address for this NFT, or the zero address if there is none
    // Query if an address is an authorized operator for another address
    procedure IsApprovedForAll(
      const owner    : TAddress;                // The address that owns the NFTs
      const &operator: TAddress;                // The address that acts on behalf of the owner
      const callback : TProc<Boolean, IError>); // True if `operator` is an approved operator for `owner`, false otherwise
  end;

  IERC721Metadata = interface
    // A descriptive name for a collection of NFTs in this contract
    procedure Name(const callback: TProc<string, IError>);
    // An abbreviated name for NFTs in this contract
    procedure Symbol(const callback: TProc<string, IError>);
    // A distinct Uniform Resource Identifier (URI) for a given asset.
    // The URI may point to a JSON file that conforms to the "ERC721 Metadata JSON Schema".
    procedure TokenURI(const tokenId: BigInteger; const callback: TProc<string, IError>);
  end;

  IERC721Enumerable = interface
    // Count NFTs tracked by this contract
    procedure TotalSupply(const callback: TProc<BigInteger, IError>);
    // Enumerate valid NFTs
    procedure TokenByIndex(
      const index   : BigInteger;                 // A counter less than `totalSupply()`
      const callback: TProc<BigInteger, IError>); // The token identifier for the `index`th NFT
    // Enumerate NFTs assigned to an owner
    procedure TokenOfOwnerByIndex(
      const owner   : TAddress;                   // An address where we are interested in NFTs owned by them
      const index   : BigInteger;                 // A counter less than `balanceOf(_owner)`
      const callback: TProc<BigInteger, IError>); // The token identifier for the `index`th NFT assigned to `owner`
  end;

  // This emits when ownership of any NFT changes by any mechanism.
  TOnTransfer = reference to procedure(
    Sender : TObject;
    From   : TAddress;
    &To    : TAddress;
    TokenId: BigInteger);

  // This emits when the approved address for an NFT is changed or
  // reaffirmed. The zero address indicates there is no approved address.
  TOnApproval = reference to procedure(
    Sender : TObject;
    Owner  : TAddress;
    Spender: TAddress;
    TokenId: BigInteger);

  // This emits when an operator is enabled or disabled for an owner.
  // The operator can manage all NFTs of the owner.
  TOnApprovalForAll = reference to procedure(
    Sender   : TObject;
    Owner    : TAddress;
    &Operator: TAddress;
    Approved : Boolean);

  TForEach = TProc<BigInteger, TProc<Boolean>>; // (tokenId, next)

  TERC721 = class(TCustomContract, IERC721, IERC721Metadata, IERC721Enumerable)
  strict private
    FLogger: ILogger;
    FOnTransfer: TOnTransfer;
    FOnApproval: TOnApproval;
    FOnApprovalForAll: TOnApprovalForAll;
    procedure SetOnTransfer(const Value: TOnTransfer);
    procedure SetOnApproval(const Value: TOnApproval);
    procedure SetOnApprovalForAll(const Value: TOnApprovalForAll);
  protected
    procedure WatchOrStop; virtual;
  public
    constructor Create(const aClient: IWeb3; const aContract: TAddress); override;
    destructor  Destroy; override;
    // IERC721
    procedure BalanceOf(
      const owner   : TAddress;
      const callback: TProc<BigInteger, IError>);
    procedure OwnerOf(
      const tokenId : BigInteger;
      const callback: TProc<TAddress, IError>);
    procedure SafeTransferFrom(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const tokenId : BigInteger;
      const callback: TProc<TTxHash, IError>);
    procedure SafeTransferFromEx(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const tokenId : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure TransferFrom(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const tokenId : BigInteger;
      const callback: TProc<TTxHash, IError>);
    procedure TransferFromEx(
      const from    : TPrivateKey;
      const &to     : TAddress;
      const tokenId : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure Approve(
      const owner   : TPrivateKey;
      const spender : TAddress;
      const tokenId : BigInteger;
      const callback: TProc<ITxReceipt, IError>);
    procedure SetApprovalForAll(
      const owner    : TPrivateKey;
      const &operator: TAddress;
      const approved : Boolean;
      const callback : TProc<ITxReceipt, IError>);
    procedure GetApproved(
      const tokenId : BigInteger;
      const callback: TProc<TAddress, IError>);
    procedure IsApprovedForAll(
      const owner    : TAddress;
      const &operator: TAddress;
      const callback : TProc<Boolean, IError>);
    // IERC721Metadata
    procedure Name(const callback: TProc<string, IError>);
    procedure Symbol(const callback: TProc<string, IError>);
    procedure TokenURI(const tokenId: BigInteger; const callback: TProc<string, IError>);
    // IERC721Enumerable
    procedure TotalSupply(const callback: TProc<BigInteger, IError>);
    procedure TokenByIndex(const index: BigInteger; const callback: TProc<BigInteger, IError>);
    procedure TokenOfOwnerByIndex(const owner: TAddress; const index: BigInteger; const callback: TProc<BigInteger, IError>);
    procedure Enumerate(const foreach: TForEach; const error: TProc<IError>; const done: TProc);
    // events
    property OnTransfer: TOnTransfer read FOnTransfer write SetOnTransfer;
    property OnApproval: TOnApproval read FOnApproval write SetOnApproval;
    property OnApprovalForAll: TOnApprovalForAll read FOnApprovalForAll write SetOnApprovalForAll;
  end;

implementation

{ TERC721}

constructor TERC721.Create(const aClient: IWeb3; const aContract: TAddress);
begin
  inherited Create(aClient, aContract);

  FLogger := web3.eth.logs.get(aClient, aContract,
    procedure(log: PLog; err: IError)
    begin
      if not Assigned(log) then
        EXIT;

      if Assigned(FOnTransfer) then
        if log^.isEvent('Transfer(address,address,uint256)') then
          FOnTransfer(Self,
                      log^.Topic[1].toAddress,  // from
                      log^.Topic[2].toAddress,  // to
                      log^.Topic[3].toUInt256); // tokenId

      if Assigned(FOnApproval) then
        if log^.isEvent('Approval(address,address,uint256)') then
          FOnApproval(Self,
                      log^.Topic[1].toAddress,  // owner
                      log^.Topic[2].toAddress,  // spender
                      log^.Topic[3].toUInt256); // tokenId

      if Assigned(FOnApprovalForAll) then
        if log^.isEvent('ApprovalForAll(address,address,bool)') then
          FOnApprovalForAll(Self,
                            log^.Topic[1].toAddress, // owner
                            log^.Topic[2].toAddress, // operator
                            log^.Data[0].toBoolean); // approved
    end);
end;

destructor TERC721.Destroy;
begin
  if FLogger.Status in [Running, Paused] then FLogger.Stop;
  inherited Destroy;
end;

procedure TERC721.SetOnTransfer(const Value: TOnTransfer);
begin
  FOnTransfer := Value;
  WatchOrStop;
end;

procedure TERC721.SetOnApproval(const Value: TOnApproval);
begin
  FOnApproval := Value;
  WatchOrStop;
end;

procedure TERC721.SetOnApprovalForAll(const Value: TOnApprovalForAll);
begin
  FOnApprovalForAll := Value;
  WatchOrStop;
end;

procedure TERC721.WatchOrStop;
begin
  if Assigned(FOnTransfer) or Assigned(FOnApproval) or Assigned(FOnApprovalForAll) then
  begin
    if FLogger.Status in [Idle, Paused] then FLogger.Start;
    EXIT;
  end;
  if FLogger.Status = Running then FLogger.Pause;
end;

procedure TERC721.BalanceOf(const owner: TAddress; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'balanceOf(address)', [owner], callback);
end;

procedure TERC721.OwnerOf(const tokenId: BigInteger; const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'ownerOf(uint256)', [web3.utils.toHex(tokenId)], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure TERC721.SafeTransferFrom(
  const from    : TPrivateKey;
  const &to     : TAddress;
  const tokenId : BigInteger;
  const callback: TProc<TTxHash, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback('', err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'safeTransferFrom(address,address,uint256)', [sender, &to, web3.utils.toHex(tokenId)], callback)
    end);
end;

procedure TERC721.SafeTransferFromEx(
  const from    : TPrivateKey;
  const &to     : TAddress;
  const tokenId : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'safeTransferFrom(address,address,uint256)', [sender, &to, web3.utils.toHex(tokenId)], callback)
    end);
end;

procedure TERC721.TransferFrom(
  const from    : TPrivateKey;
  const &to     : TAddress;
  const tokenId : BigInteger;
  const callback: TProc<TTxHash, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback('', err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'transferFrom(address,address,uint256)', [sender, &to, web3.utils.toHex(tokenId)], callback)
    end);
end;

procedure TERC721.TransferFromEx(
  const from    : TPrivateKey;
  const &to     : TAddress;
  const tokenId : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  from.GetAddress
    .ifErr(procedure(err: IError)
    begin
      callback(nil, err)
    end)
    .&else(procedure(sender: TAddress)
    begin
      web3.eth.write(Client, from, Contract, 'transferFrom(address,address,uint256)', [sender, &to, web3.utils.toHex(tokenId)], callback)
    end);
end;

procedure TERC721.Approve(
  const owner   : TPrivateKey;
  const spender : TAddress;
  const tokenId : BigInteger;
  const callback: TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, owner, Contract, 'approve(address,uint256)', [spender, web3.utils.toHex(tokenId)], callback);
end;

procedure TERC721.SetApprovalForAll(
  const owner    : TPrivateKey;
  const &operator: TAddress;
  const approved : Boolean;
  const callback : TProc<ITxReceipt, IError>);
begin
  web3.eth.write(Client, owner, Contract, 'setApprovalForAll(address,bool)', [&operator, approved], callback);
end;

procedure TERC721.GetApproved(const tokenId: BigInteger; const callback: TProc<TAddress, IError>);
begin
  web3.eth.call(Client, Contract, 'getApproved(uint256)', [web3.utils.toHex(tokenId)], procedure(hex: string; err: IError)
  begin
    if Assigned(err) then
      callback(TAddress.Zero, err)
    else
      callback(TAddress.Create(hex), nil);
  end);
end;

procedure TERC721.IsApprovedForAll(
  const owner    : TAddress;
  const &operator: TAddress;
  const callback : TProc<Boolean, IError>);
begin
  web3.eth.call(Client, Contract, 'isApprovedForAll(address,address)', [owner, &operator], callback);
end;

procedure TERC721.Name(const callback: TProc<string, IError>);
begin
  web3.eth.call(Client, Contract, 'name()', [], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC721.Symbol(const callback: TProc<string, IError>);
begin
  web3.eth.call(Client, Contract, 'symbol()', [], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC721.TokenURI(const tokenId: BigInteger; const callback: TProc<string, IError>);
begin
  web3.eth.call(Client, Contract, 'tokenURI(uint256)', [web3.utils.toHex(tokenId)], procedure(tup: TTuple; err: IError)
  begin
    if Assigned(err) then
      callback('', err)
    else
      callback(tup.ToString, nil);
  end);
end;

procedure TERC721.TotalSupply(const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'totalSupply()', [], callback);
end;

procedure TERC721.TokenByIndex(const index: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'tokenByIndex(uint256)', [web3.utils.toHex(index)], callback);
end;

procedure TERC721.TokenOfOwnerByIndex(const owner: TAddress; const index: BigInteger; const callback: TProc<BigInteger, IError>);
begin
  web3.eth.call(Client, Contract, 'tokenOfOwnerByIndex(address,uint256)', [owner, web3.utils.toHex(index)], callback);
end;

procedure TERC721.Enumerate(const foreach: TForEach; const error: TProc<IError>; const done: TProc);
begin
  var next: TProc<Integer, BigInteger>; // (index, length)

  next := procedure(idx: Integer; len: BigInteger)
  begin
    if idx >= len then
    begin
      done;
      EXIT;
    end;
    Self.TokenByIndex(idx, procedure(tokenId: BigInteger; err: IError)
    begin
      if Assigned(err) then
      begin
        error(err);
        next(idx + 1, len);
      end
      else
        foreach(tokenId, procedure(continue: Boolean)
        begin
          if continue then
            next(idx + 1, len)
          else
            done;
        end);
    end);
  end;

  Self.TotalSupply(procedure(len: BigInteger; err: IError)
  begin
    if Assigned(err) then
    begin
      error(err);
      done;
      EXIT;
    end;
    if len = 0 then
    begin
      done;
      EXIT;
    end;
    next(0, len);
  end);
end;

end.
