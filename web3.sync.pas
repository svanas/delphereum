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
  System.Threading,
  // Velthuis' BigNumbers
  Velthuis.BigIntegers;

type
  ICriticalThing = interface
    procedure Enter;
    procedure Leave;
  end;

  TCriticalThing = class abstract(TInterfacedObject, ICriticalThing)
  strict private
    Inner: TCriticalSection;
  public
    procedure Enter;
    procedure Leave;
    constructor Create; virtual;
    destructor Destroy; override;
  end;

type
  ICriticalGeneric<T> = interface(ICriticalThing)
    function Get: T;
    procedure Put(const Value: T);
  end;

  TCriticalGeneric<T> = class(TCriticalThing, ICriticalGeneric<T>)
  strict protected
    Inner: T;
  public
    function Get: T;
    procedure Put(const Value: T);
    constructor Create(const Value: T); reintroduce;
  end;

type
  ICriticalInt64 = interface(ICriticalGeneric<Int64>)
    function Inc: Int64;
  end;

  TCriticalInt64 = class(TCriticalGeneric<Int64>, ICriticalInt64)
  public
    function Inc: Int64;
  end;

type
  ICriticalBigInt = interface(ICriticalGeneric<BigInteger>)
    function Inc: BigInteger;
  end;

  TCriticalBigInt = class(TCriticalGeneric<BigInteger>, ICriticalBigInt)
  public
    function Inc: BigInteger;
  end;

type
  ICriticalQueue<T> = interface(ICriticalThing)
    function  Length: Integer;
    procedure Add(const Item: T);
    function  First: T;
    function  Get(Index: Integer): T;
    procedure Delete(Index, Count: Integer);
  end;

  TCriticalQueue<T> = class(TCriticalThing, ICriticalQueue<T>)
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
  TCriticalList = class abstract(TCriticalThing)
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

type
  TCriticalDictionary<TKey,TValue> = class(TDictionary<TKey,TValue>)
  strict private
    Inner: TCriticalSection;
  public
    procedure Enter;
    procedure Leave;
    destructor Destroy; override;
  end;

function ThreadPool: TThreadPool;

implementation

var
  _ThreadPool: TThreadPool = nil;

function ThreadPool: TThreadPool;
begin
  if not Assigned(_ThreadPool) then
    _ThreadPool := TThreadPool.Create;
  Result := _ThreadPool;
end;

{ TCriticalThing }

constructor TCriticalThing.Create;
begin
  inherited Create;
  Inner := TCriticalSection.Create;
end;

destructor TCriticalThing.Destroy;
begin
  if Assigned(Inner) then Inner.Free;
  inherited Destroy;
end;

procedure TCriticalThing.Enter;
begin
  Inner.Enter;
end;

procedure TCriticalThing.Leave;
begin
  Inner.Leave;
end;

{ TCriticalGeneric }

constructor TCriticalGeneric<T>.Create(const Value: T);
begin
  inherited Create;
  Inner := Value;
end;

function TCriticalGeneric<T>.Get: T;
begin
  Result := Inner;
end;

procedure TCriticalGeneric<T>.Put(const Value: T);
begin
  Inner := Value;
end;

{ TCriticalInt64 }

function TCriticalInt64.Inc: Int64;
begin
  Inner  := Inner + 1;
  Result := Inner;
end;

{ TCriticalBigInt }

function TCriticalBigInt.Inc: BigInteger;
begin
  Inner  := Inner + 1;
  Result := Inner;
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

{ TCriticalDictionary }

destructor TCriticalDictionary<TKey,TValue>.Destroy;
begin
  if Assigned(Inner) then Inner.Free;
  inherited Destroy;
end;

procedure TCriticalDictionary<TKey,TValue>.Enter;
begin
  if not Assigned(Inner) then
    Inner := TCriticalSection.Create;
  Inner.Enter;
end;

procedure TCriticalDictionary<TKey,TValue>.Leave;
begin
  if Assigned(Inner) then Inner.Leave;
end;

end.
