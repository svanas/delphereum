{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2023 Stefan van As <svanas@runbox.com>              }
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

unit web3.error;

{$I web3.inc}

interface

uses
  // web3
  web3;

type
  // You can safely ignore this error and continue execution if you want
  ISilent = interface(IError)
  ['{07D302E5-B5F2-479C-8606-574D2F8BCF4F}']
  end;
  TSilent = class(TError, ISilent);

  INotImplemented = interface(IError)
  ['{FFB9DA94-0C40-4A7C-9C47-CD790E3435A2}']
  end;
  TNotImplemented = class(TError, INotImplemented)
  public
    constructor Create;
  end;

  // User denied transaction signature
  ISignatureDenied = interface(IError)
  ['{AFFFBC21-3686-44A8-9034-2B38B3001B02}']
  end;
  TSignatureDenied = class(TError, ISignatureDenied)
  public
    constructor Create;
  end;

  // cancelled by user
  ICancelled = interface(IError)
  ['{EB6305B0-A310-43ED-A868-8BCB3334B11F}']
  end;
  TCancelled = class(TError, ICancelled)
  public
    constructor Create;
  end;

procedure show(const msg: string); overload;
procedure show(chain: TChain; const err: IError); overload;

implementation

uses
  // Delphi
  System.Classes,
  System.SysUtils,
  System.UITypes,
{$IFDEF FMX}
  FMX.Dialogs,
{$ELSE}
  VCL.Dialogs,
{$ENDIF}
  // web3
  web3.eth.tx;

{ TNotImplemented }

constructor TNotImplemented.Create;
begin
  inherited Create('Not implemented');
end;

{ TSignatureDenied }

constructor TSignatureDenied.Create;
begin
  inherited Create('User denied transaction signature');
end;

{ TCancelled }

constructor TCancelled.Create;
begin
  inherited Create('Cancelled by user');
end;

{ global functions }

procedure show(const msg: string);
begin
  TThread.Synchronize(nil, procedure
  begin
{$WARN SYMBOL_DEPRECATED OFF}
    MessageDlg(msg, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
{$WARN SYMBOL_DEPRECATED DEFAULT}
  end);
end;

procedure show(chain: TChain; const err: IError);
begin
  if Supports(err, ISignatureDenied) then
    EXIT;
  TThread.Synchronize(nil, procedure
  var
    txError: ITxError;
  begin
{$WARN SYMBOL_DEPRECATED OFF}
    if Supports(err, ITxError, txError) then
    begin
      if MessageDlg(
        Format(
          '%s. Would you like to view this transaction on etherscan?',
          [err.Message]
        ),
        TMsgDlgType.mtError, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0
      ) = mrYes then
        openTransaction(chain, txError.Hash);
      EXIT;
    end;
    MessageDlg(err.Message, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
{$WARN SYMBOL_DEPRECATED DEFAULT}
  end);
end;

end.
