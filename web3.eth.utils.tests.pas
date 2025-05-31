{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2018 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.utils.tests;

{$I web3.inc}

interface

uses
  // Delphi
  System.SysUtils,
  // DUnitX
  DUnitX.TestFramework,
  // web3
  web3;

type
  TCustomTests = class
  strict protected
    procedure Execute(const proc: TProc<TProc, TProc<IError>>);
  end;

type
  [TestFixture]
  TTests = class(TCustomTests)
  public
    [Test]
    procedure FromWei;
    [Test]
    procedure ToWei1;
    [Test]
    procedure ToWei2;
    [Test]
    procedure ToWei3;
    [Test]
    procedure ToWei4;
    [Test]
    procedure ToWei5;
    [Test]
    procedure ToWei6;
    [Test]
    procedure WeiToWei;
    [Test]
    procedure ToChecksum;
    [Test]
    procedure IsEOA;
  end;

implementation

uses
  // Delphi
  System.Classes,
  // web3
  web3.eth.types, web3.eth.utils;

// executes an async test. the text is expected to call back into the 1st arg on success, otherwise the 2nd ags when an error occurred
procedure TCustomTests.Execute(const proc: TProc<TProc, TProc<IError>>);
const
  TEST_TIMEOUT  = 60000; // 60 seconds
  TEST_INTERVAL = 100;   // 0.1 second
begin
  var done: Boolean := False;
  var err : IError  := nil;

  proc(procedure
  begin
    done := True;
  end, procedure(error: IError)
  begin
    err := error;
  end);

  var waited: UInt16 := 0;
  while (err = nil) and (not done) and (waited < TEST_TIMEOUT) do
  begin
    TThread.Sleep(TEST_INTERVAL); waited := waited + TEST_INTERVAL;
  end;

  if Assigned(err) then Assert.Fail(err.Message) else if waited >= TEST_TIMEOUT then Assert.Fail('test timed out');
end;

procedure TTests.FromWei;
begin
  Assert.IsTrue(
        (web3.eth.utils.fromWei(1000000000000000000, wei)    = '1000000000000000000')
    and (web3.eth.utils.fromWei(1000000000000000000, kwei)   = '1000000000000000')
    and (web3.eth.utils.fromWei(1000000000000000000, mwei)   = '1000000000000')
    and (web3.eth.utils.fromWei(1000000000000000000, gwei)   = '1000000000')
    and (web3.eth.utils.fromWei(1000000000000000000, szabo)  = '1000000')
    and (web3.eth.utils.fromWei(1000000000000000000, finney) = '1000')
    and (web3.eth.utils.fromWei(1000000000000000000, ether)  = '1')
    and (web3.eth.utils.fromWei(1000000000000000000, kether) = '0.001')
    and (web3.eth.utils.fromWei(1000000000000000000, grand)  = '0.001')
    and (web3.eth.utils.fromWei(1000000000000000000, mether) = '0.000001')
    and (web3.eth.utils.fromWei(1000000000000000000, gether) = '0.000000001')
    and (web3.eth.utils.fromWei(1000000000000000000, tether) = '0.000000000001')
  );
end;

procedure TTests.ToWei1;
type
  TTestCase = record
    &to   : TDenomination;
    output: string;
  end;
const
  TEST_CASES: array[0..14] of TTestCase = (
    (&to: wei;      output: '1'),
    (&to: kwei;     output: '1000'),
    (&to: babbage;  output: '1000'),
    (&to: mwei;     output: '1000000'),
    (&to: lovelace; output: '1000000'),
    (&to: gwei;     output: '1000000000'),
    (&to: shannon;  output: '1000000000'),
    (&to: szabo;    output: '1000000000000'),
    (&to: finney;   output: '1000000000000000'),
    (&to: ether;    output: '1000000000000000000'),
    (&to: kether;   output: '1000000000000000000000'),
    (&to: grand;    output: '1000000000000000000000'),
    (&to: mether;   output: '1000000000000000000000000'),
    (&to: gether;   output: '1000000000000000000000000000'),
    (&to: tether;   output: '1000000000000000000000000000000')
  );
begin
  for var TEST_CASE in TEST_CASES do
  begin
    web3.eth.utils.toWei('1', TEST_CASE.&to)
      .ifErr(procedure(err: IError)
      begin
        Assert.Fail(err.Message)
      end)
      .&else(procedure(wei: TWei)
      begin
        Assert.IsTrue(wei = TWei.Create(TEST_CASE.output))
      end);
  end;
end;

procedure TTests.ToWei2;
begin
  web3.eth.utils.toWei('1', kwei)
    .ifErr(procedure(err: IError)
    begin
      Assert.Fail(err.Message)
    end)
    .&else(procedure(wei1: TWei)
    begin
      web3.eth.utils.toWei('1', femtoether)
        .ifErr(procedure(err: IError)
        begin
          Assert.Fail(err.Message)
        end)
        .&else(procedure(wei2: TWei)
        begin
          Assert.IsTrue(wei1 = wei2)
        end);
    end);
end;

procedure TTests.ToWei3;
begin
  web3.eth.utils.toWei('1', szabo)
    .ifErr(procedure(err: IError)
    begin
      Assert.Fail(err.Message)
    end)
    .&else(procedure(wei1: TWei)
    begin
      web3.eth.utils.toWei('1', microether)
        .ifErr(procedure(err: IError)
        begin
          Assert.Fail(err.Message)
        end)
        .&else(procedure(wei2: TWei)
        begin
          Assert.IsTrue(wei1 = wei2)
        end);
    end);
end;

procedure TTests.ToWei4;
begin
  web3.eth.utils.toWei('1', finney)
    .ifErr(procedure(err: IError)
    begin
      Assert.Fail(err.Message)
    end)
    .&else(procedure(wei1: TWei)
    begin
      web3.eth.utils.toWei('1', milliether)
        .ifErr(procedure(err: IError)
        begin
          Assert.Fail(err.Message)
        end)
        .&else(procedure(wei2: TWei)
        begin
          Assert.IsTrue(wei1 = wei2)
        end);
    end);
end;

procedure TTests.ToWei5;
begin
  web3.eth.utils.toWei('1', milli)
    .ifErr(procedure(err: IError)
    begin
      Assert.Fail(err.Message)
    end)
    .&else(procedure(wei1: TWei)
    begin
      web3.eth.utils.toWei('1', milliether)
        .ifErr(procedure(err: IError)
        begin
          Assert.Fail(err.Message)
        end)
        .&else(procedure(wei2: TWei)
        begin
          Assert.IsTrue(wei1 = wei2)
        end);
    end);
end;

procedure TTests.ToWei6;
begin
  web3.eth.utils.toWei('1', milli)
    .ifErr(procedure(err: IError)
    begin
      Assert.Fail(err.Message)
    end)
    .&else(procedure(wei1: TWei)
    begin
      web3.eth.utils.toWei('1000', micro)
        .ifErr(procedure(err: IError)
        begin
           Assert.Fail(err.Message)
        end)
        .&else(procedure(wei2: TWei)
        begin
          Assert.IsTrue(wei1 = wei2)
        end);
    end);
end;

procedure TTests.WeiToWei;
const
  TEST_CASES: array[0..17] of string = (
    '0',
    '0.1',
    '0.01',
    '0.001',
    '0.0001',
    '0.00001',
    '0.000001',
    '0.0000001',
    '0.00000001',
    '1',
    '1.1',
    '1.01',
    '1.001',
    '1.0001',
    '1.00001',
    '1.000001',
    '1.0000001',
    '1.00000001');
begin
  for var TEST_CASE in TEST_CASES do
  begin
    web3.eth.utils.toWei(TEST_CASE, ether)
      .ifErr(procedure(err: IError)
      begin
        Assert.Fail(err.Message)
      end)
      .&else(procedure(wei: TWei)
      begin
        Assert.AreEqual(web3.eth.utils.fromWei(wei, ether), TEST_CASE)
      end);
  end;
end;

procedure TTests.ToChecksum;
const
  TEST_CASES: array[0..3] of string = (
    '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
    '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
    '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
    '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb'
  );
begin
  for var TEST_CASE in TEST_CASES do
  begin
    Assert.AreEqual(
      string(TAddress.Create(TEST_CASE.ToUpper).ToChecksum), TEST_CASE, False);
    Assert.AreEqual(
      string(TAddress.Create(TEST_CASE.ToLower).ToChecksum), TEST_CASE, False);
  end;
end;

procedure TTests.IsEOA;
begin
  Self.Execute(procedure(ok: TProc; error: TProc<IError>)
  begin
    const client: IWeb3 = TWeb3.Create(Ethereum.SetRPC('https://eth.llamarpc.com'));
    // test a random address that does not exist on-chain (expected result: EOA)
    TPrivateKey.Generate.GetAddress
      .ifErr(procedure(err: IError)
      begin
        error(err)
      end)
      .&else(procedure(address: TAddress)
      begin
        address.IsEOA(client, procedure(eoa: Boolean; err: IError)
        begin
          if Assigned(err) then
            error(err)
          else
            if not eoa then
              error(TError.Create('random off-chain address is not EOA, expected EOA'))
            else
              // test an address that does exist on-chain (expected result: EOA)
              TAddress.Create('0x0000000000000000000000000000000000000000').IsEOA(client, procedure(eoa: Boolean; err: IError)
              begin
                if Assigned(err) then
                  error(err)
                else
                  if not eoa then
                    error(TError.Create('0x0000000000000000000000000000000000000000 is not EOA, expected EOA'))
                  else
                    // test an ERC-20 smart contract (expected result: not an EOA)
                    TAddress.Create('0xdAC17F958D2ee523a2206206994597C13D831ec7').IsEOA(client, procedure(eoa: Boolean; err: IError)
                    begin
                      if Assigned(err) then
                        error(err)
                      else
                        if eoa then
                          error(TError.Create('Tether''s ERC-20 is an EOA, expected not EOA'))
                        else
                          // test an EOA that got ERC-7702-migrated to a smart wallet (expected result: EOA)
                          TAddress.Create('0x6cE7c78a5FaE9749Ec0f9CFf3d7696bcfc25f49B').IsEOA(client, procedure(eoa: Boolean; err: IError)
                          begin
                            if Assigned(err) then
                              error(err)
                            else
                              if not eoa then
                                error(TError.Create('EIP-7702-migrated address is not EOA, expected EOA'))
                              else
                                ok
                          end);
                    end);
              end);
        end);
      end);
  end);
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
