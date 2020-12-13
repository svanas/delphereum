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

unit web3.sync;

{$I web3.inc}

interface

uses
  // Delphi
  System.Generics.Collections,
  System.RTLConsts,
  System.SyncObjs,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  ICriticalSingleton = interface
    procedure Enter;
    procedure Leave;
  end;

  TCriticalSingleton = class abstract(TInterfacedObject, ICriticalSingleton)
  strict private
    Inner: TCriticalSection;
  public
    procedure Enter;
    procedure Leave;
    constructor Create; virtual;
    destructor Destroy; override;
  end;

type
  ICriticalInt64 = interface(ICriticalSingleton)
    function  Inc: Int64;
    function  Get: Int64;
    procedure Put(Value: Int64);
  end;

  TCriticalInt64 = class(TCriticalSingleton, ICriticalInt64)
  strict private
    Inner: Int64;
  public
    function  Inc: Int64;
    function  Get: Int64;
    procedure Put(Value: Int64);
    constructor Create(Value: Int64); reintroduce;
  end;

type
  ICriticalBigInt = interface(ICriticalSingleton)
    function  Inc: BigInteger;
    function  Get: BigInteger;
    procedure Put(Value: BigInteger);
  end;

  TCriticalBigInt = class(TCriticalSingleton, ICriticalBigInt)
  strict private
    Inner: BigInteger;
  public
    function  Inc: BigInteger;
    function  Get: BigInteger;
    procedure Put(Value: BigInteger);
    constructor Create(Value: BigInteger); reintroduce;
  end;

type
  ICriticalQueue<T> = interface(ICriticalSingleton)
    function  Length: Integer;
    procedure Add(const Item: T);
    function  First: T;
    function  Get(Index: Integer): T;
    procedure Delete(Index, Count: Integer);
  end;

  TCriticalQueue<T> = class(TCriticalSingleton, ICriticalQueue<T>)
  strict private
    Inner: TArray<T>;
  public
    function  Length: Integer;
    procedure Add(const Item: T);
    function  First: T;
    function  Get(Index: Integer): T;
    procedure Delete(Index, Count: Integer);
  end;

type
  TCriticalList = class abstract(TCriticalSingleton)
  strict private
    Inner: TList<IInterface>;
  strict protected
    function  Get(Index: Integer): IInterface;
    procedure Put(Index: Integer; const Item: IInterface);
    procedure Clear;
    procedure Delete(Index: Integer);
    function  First: IInterface;
    function  Add(const Item: IInterface): Integer;
    function  Count: Integer;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TCriticalSingleton }

constructor TCriticalSingleton.Create;
begin
  inherited Create;
  Inner := TCriticalSection.Create;
end;

destructor TCriticalSingleton.Destroy;
begin
  if Assigned(Inner) then Inner.Free;
  inherited Destroy;
end;

procedure TCriticalSingleton.Enter;
begin
  Inner.Enter;
end;

procedure TCriticalSingleton.Leave;
begin
  Inner.Leave;
end;

{ TCriticalInt64 }

constructor TCriticalInt64.Create(Value: Int64);
begin
  inherited Create;
  Inner := Value;
end;

function TCriticalInt64.Inc: Int64;
begin
  Inner  := Inner + 1;
  Result := Inner;
end;

function TCriticalInt64.Get: Int64;
begin
  Result := Inner;
end;

procedure TCriticalInt64.Put(Value: Int64);
begin
  Inner := Value;
end;

{ TCriticalBigInt }

constructor TCriticalBigInt.Create(Value: BigInteger);
begin
  inherited Create;
  Inner := Value;
end;

function TCriticalBigInt.Inc: BigInteger;
begin
  Inner  := Inner + 1;
  Result := Inner;
end;

function TCriticalBigInt.Get: BigInteger;
begin
  Result := Inner;
end;

procedure TCriticalBigInt.Put(Value: BigInteger);
begin
  Inner := Value;
end;

{ TCriticalQueue<T> }

function TCriticalQueue<T>.Length: Integer;
begin
  Result := System.Length(Inner);
end;

procedure TCriticalQueue<T>.Add(const Item: T);
begin
  Inner := Inner + [Item];
end;

function TCriticalQueue<T>.First: T;
begin
  Result := Get(0);
end;

function TCriticalQueue<T>.Get(Index: Integer): T;
begin
  Result := Inner[Index];
end;

procedure TCriticalQueue<T>.Delete(Index: Integer; Count: Integer);
begin
  System.Delete(Inner, Index, Count);
end;

{ TCriticalList }

constructor TCriticalList.Create;
begin
  inherited Create;
  Inner := TList<IInterface>.Create;
end;

destructor TCriticalList.Destroy;
begin
  Clear;
  if Assigned(Inner) then Inner.Free;
  inherited Destroy;
end;

procedure TCriticalList.Clear;
var
  I: Integer;
begin
  if Assigned(Inner) then
  begin
    for I := 0 to Pred(Inner.Count) do
      Inner[I] := nil;
    Inner.Clear;
  end;
end;

procedure TCriticalList.Delete(Index: Integer);
begin
  if (Index < 0) or (Index >= Count) then
    Inner.Error(SListIndexError, Index);
  Inner[Index] := nil;
  Inner.Delete(Index);
end;

function TCriticalList.First: IInterface;
begin
  Result := Get(0);
end;

function TCriticalList.Get(Index: Integer): IInterface;
begin
  if (Index < 0) or (Index >= Count) then
    Inner.Error(SListIndexError, Index);
  Result := Inner[Index];
end;

function TCriticalList.Count: Integer;
begin
  Result := Inner.Count;
end;

function TCriticalList.Add(const Item: IInterface): Integer;
begin
  Result := Inner.Add(nil);
  Inner[Result] := Item;
end;

procedure TCriticalList.Put(Index: Integer; const Item: IInterface);
begin
  if (Index < 0) or (Index >= Count) then
    Inner.Error(SListIndexError, Index);
  Inner[Index] := Item;
end;

end.
