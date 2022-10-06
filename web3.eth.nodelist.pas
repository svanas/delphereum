{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2022 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.nodelist;

{$I web3.inc}

interface

uses
  // Delphi
  System.JSON,
  System.SysUtils,
  System.Types,
  // web3
  web3;

type
  TOnline = (Unknown, Offline, Online);

  INode = interface
    function Chain: TChain;
    function Free: Boolean;
    function Name: string;
    procedure Online(callback: TProc<TOnline, IError>);
    function Rpc: string;
    function SetTag(const Value: IInterface): INode;
    function Tag: IInterface;
    function Wss: string;
  end;

  TNodes = TArray<INode>;

  TNodesHelper = record helper for TNodes
    procedure Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
    function Length: Integer;
  end;

function get(chain: TChain; callback: TProc<TJsonArray, IError>): IAsyncResult; overload;
function get(chain: TChain; callback: TProc<TNodes, IError>): IAsyncResult; overload;

implementation

uses
  // Delphi
  System.Classes,
  System.Generics.Collections,
{$IFDEF FMX}
  FMX.Dialogs,
{$ELSE}
  VCL.Dialogs,
{$ENDIF}
  // web3
  web3.http,
  web3.json;

{----------------------------------- TNode ------------------------------------}

resourcestring
  RS_API_KEY = 'Please paste your API key';

type
  TNode = class(TCustomDeserialized<TJsonObject>, INode)
  private
    FChain: TChain;
    FFree : Boolean;
    FName : string;
    FRpc  : string;
    FTag  : IInterface;
    FWss  : string;
  public
    function Chain: TChain;
    function Free: Boolean;
    function Name: string;
    procedure Online(callback: TProc<TOnline, IError>);
    function Rpc: string;
    function SetTag(const Value: IInterface): INode;
    function Tag: IInterface;
    function Wss: string;
    constructor Create(aChain: TChain; const aJsonValue: TJsonObject); reintroduce;
  end;

constructor TNode.Create(aChain: TChain; const aJsonValue: TJsonObject);
begin
  inherited Create(aJsonValue);
  FChain := aChain;
  FName  := getPropAsStr(aJsonValue, 'name');
  FRpc   := getPropAsStr(aJsonValue, 'rpc');
  FWss   := getPropAsStr(aJsonValue, 'wss');
  FFree  := FRpc.IndexOf('$apiKey') = -1;
end;

function TNode.Chain: TChain;
begin
  Result := FChain;
end;

function TNode.Free: Boolean;
begin
  Result := FFree;
end;

function TNode.Name: string;
begin
  Result := FName;
end;

procedure TNode.Online(callback: TProc<TOnline, IError>);
begin
  if Self.Rpc.IndexOf('$apiKey') > -1 then
  begin
    callback(TOnline.Unknown, nil);
    EXIT;
  end;
  const client: IWeb3 = TWeb3.Create(Self.Chain, Self.Rpc);
  client.Call('eth_chainId', [], procedure(response: TJsonObject; err: IError)
  begin
    if not Assigned(err) then
      callback(TOnline.Online, err)
    else
      callback(TOnline.Offline, err);
  end);
end;

function TNode.Rpc: string;
begin
  if FRpc.IndexOf('$apiKey') > -1 then
  begin
    var apiKey: string;
    TThread.Synchronize(nil, procedure
    begin
{$WARN SYMBOL_DEPRECATED OFF}
      apiKey := Trim(InputBox(Self.Name, RS_API_KEY, ''));
{$WARN SYMBOL_DEPRECATED DEFAULT}
      if apiKey <> '' then
        FRpc := FRpc.Replace('$apiKey', apiKey);
    end);
  end;
  Result := FRpc;
end;

function TNode.SetTag(const Value: IInterface): INode;
begin
  FTag := Value;
  Result := Self;
end;

function TNode.Tag: IInterface;
begin
  Result := FTag;
end;

function TNode.Wss: string;
begin
  if FWss.IndexOf('$apiKey') > -1 then
  begin
    var apiKey: string;
    TThread.Synchronize(nil, procedure
    begin
{$WARN SYMBOL_DEPRECATED OFF}
      apiKey := Trim(InputBox(Self.Name, RS_API_KEY, ''));
{$WARN SYMBOL_DEPRECATED DEFAULT}
      if apiKey <> '' then
        FWss := FWss.Replace('$apiKey', apiKey);
    end);
  end;
  Result := FWss;
end;

{------------------------------- TNodesHelper ---------------------------------}

procedure TNodesHelper.Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
begin
  var next: TProc<TNodes, Integer>;

  next := procedure(nodes: TNodes; idx: Integer)
  begin
    if idx >= nodes.Length then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    foreach(idx, procedure
    begin
      next(nodes, idx + 1);
    end);
  end;

  if Self.Length = 0 then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  next(Self, 0);
end;

function TNodesHelper.Length: Integer;
begin
  Result := System.Length(Self);
end;

{------------------------------ public functions ------------------------------}

function get(chain: TChain; callback: TProc<TJsonArray, IError>): IAsyncResult;
begin
  Result := web3.http.get('https://raw.githubusercontent.com/svanas/ethereum-node-list/main/ethereum-node-list.json', [], procedure(obj: TJsonObject; err: IError)
  begin
    if Assigned(err) or not Assigned(obj) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const chains = getPropAsArr(obj, 'chains');
    for var C in chains do
      if getPropAsInt(C, 'id') = chain.Id then
      begin
        callback(getPropAsArr(C, 'nodes'), nil);
        EXIT;
      end;
  end);
end;

function get(chain: TChain; callback: TProc<TNodes, IError>): IAsyncResult;
begin
  Result := get(chain, procedure(arr: TJsonArray; err: IError)
  begin
    if Assigned(err) or not Assigned(arr) then
    begin
      callback(nil, err);
      EXIT;
    end;
    const result = (function: TNodes
    begin
      SetLength(Result, arr.Count);
      for var I := 0 to Pred(arr.Count) do
        Result[I] := TNode.Create(chain, arr[I] as TJsonObject);
    end)();
    callback(result, nil);
  end);
end;

end.
