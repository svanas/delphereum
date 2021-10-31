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

unit web3.eth.tx.tests;

{$I web3.inc}

interface

uses
  // DUnitX
  DUnitX.TestFramework;

type
  [TestFixture]
  TTests = class
  public
    [Test]
    procedure TestCase1;
  end;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3,
  web3.eth.tx;

procedure TTests.TestCase1;
begin
  Assert.AreEqual(
    web3.eth.tx.signTransactionLegacy(
      Mainnet,
      9,
      '4646464646464646464646464646464646464646464646464646464646464646',
      '0x3535353535353535353535353535353535353535',
      1000000000000000000,
      '',
      20000000000,
      21000
    ).ToLower,
    '0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
