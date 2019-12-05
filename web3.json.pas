{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.json;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils;

function marshal  (const obj: TJsonValue): string;
function unmarshal(const val: string)    : TJsonObject;

function getPropAsStr(obj: TJsonValue; const name: string; const def: string = ''): string;
function getPropAsInt(obj: TJsonValue; const name: string; def: Integer = 0): Integer;
function getPropAsObj(obj: TJsonValue; const name: string): TJsonObject;
function getPropAsArr(obj: TJsonValue; const name: string): TJsonArray;

function quoteString(const S: string; Quote: Char = '"'): string;

implementation

function marshal(const obj: TJsonValue): string;
var
  B: TBytes;
  I: Integer;
begin
  Result := '';

  if not Assigned(obj) then
    EXIT;

  I := obj.EstimatedByteSize;
  if I <= 0 then
    EXIT;
  SetLength(B, I);

  I := obj.ToBytes(B, 0);
  if I <= 0 then
    SetLength(B, 0)
  else
    SetLength(B, I);

  Result := TEncoding.UTF8.GetString(B);
end;

function unmarshal(const val: string): TJsonObject;
var
  S: string;
  V: TJsonValue;
begin
  Result := nil;

  S := val.Trim;

  if (S = '')
  or (S[Low(S)] <> '{')
  or (S[S.Length] <> '}') then
    S := '{}';

  V := TJsonObject.ParseJsonValue(S);

  if Assigned(V) then
    if V is TJsonObject then
      Result := TJsonObject(V)
    else
      V.Free;
end;

function getPropAsStr(obj: TJsonValue; const name: string; const def: string): string;
var
  P: TJsonPair;
begin
  Result := def;
  if not Assigned(obj) then
    EXIT;
  if not(obj is TJsonObject) then
    EXIT;
  P := TJsonObject(obj).Get(name);
  if Assigned(P) then
    if Assigned(P.JsonValue) then
    begin
      if P.JsonValue is TJsonString then
        Result := TJsonString(P.JsonValue).Value
      else
        Result := P.JsonValue.ToString;
      if SameText(Result, 'null') or SameText(Result, 'undefined') then
        Result := def;
    end;
end;

function getPropAsInt(obj: TJsonValue; const name: string; def: Integer): Integer;
var
  P: TJsonPair;
begin
  Result := def;
  if not Assigned(obj) then
    EXIT;
  if not(obj is TJsonObject) then
    EXIT;
  P := TJsonObject(obj).Get(name);
  if Assigned(P) then
    if Assigned(P.JsonValue) then
      if P.JsonValue is TJsonNumber then
        Result := TJsonNumber(P.JsonValue).AsInt
      else
        if P.JsonValue is TJsonString then
          Result := StrToIntDef(TJsonString(P.JsonValue).Value, def)
        else
          Result := def;
end;

function getPropAsObj(obj: TJsonValue; const name: string): TJsonObject;
var
  P: TJsonPair;
begin
  Result := nil;
  if not Assigned(obj) then
    EXIT;
  if not(obj is TJsonObject) then
    EXIT;
  P := TJsonObject(obj).Get(name);
  if Assigned(P) then
    if Assigned(P.JsonValue) then
      if P.JsonValue is TJsonObject then
        Result := TJsonObject(P.JsonValue);
end;

function getPropAsArr(obj: TJsonValue; const name: string): TJsonArray;
var
  P: TJsonPair;
begin
  Result := nil;
  if not Assigned(obj) then
    EXIT;
  if not(obj is TJsonObject) then
    EXIT;
  P := TJsonObject(obj).Get(name);
  if Assigned(P) then
    if Assigned(P.JsonValue) then
      if P.JsonValue is TJsonArray then
        Result := TJsonArray(P.JsonValue);
end;

function quoteString(const S: string; Quote: Char): string;
var
  I: Integer;
begin
  Result := S;
  if Length(Result) > 0 then
  begin
    // add extra backslash is there is a backslash, for example: c:\ --> c:\\
    I := Low(Result);
    while I <= Length(Result) do
      if Result[I] = '\' then
      begin
        Result := Copy(Result, 1, I) + '\' + Copy(Result, I + 1, Length(Result));
        I := I + 2;
      end
      else
        Inc(I);
    // add backslash if there is a double quote, for example: "a" --> \"a\"
    I := Low(Result);
    while I <= Length(Result) do
      if Result[I] = Quote then
      begin
          Result := Copy(Result, 1, I - 1) + '\' + Copy(Result, I, Length(Result));
          I := I + 2;
      end
      else
        Inc(I);
  end;
  Result := Quote + Result + Quote;
end;

end.
