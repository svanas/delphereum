{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2019 Stefan van As <svanas@runbox.com>              }
{           Github Repository <https://github.com/svanas/delphereum>           }
{                                                                              }
{   Distributed under Creative Commons NonCommercial (aka CC BY-NC) license.   }
{                                                                              }
{******************************************************************************}

unit web3.eth.ens.tests;

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
    [Test]
    procedure TestCase2;
    [Test]
    procedure TestCase3;
    [Test]
    procedure TestCase4;
  end;

implementation

uses
  // Delphi
  System.SysUtils,
  // web3
  web3.eth.ens;

procedure TTests.TestCase1;
begin
  Assert.AreEqual(
    web3.eth.ens.namehash(''),
    '0x0000000000000000000000000000000000000000000000000000000000000000'
  );
end;

procedure TTests.TestCase2;
begin
  Assert.AreEqual(
    web3.eth.ens.namehash('eth').ToLower,
    '0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae'
  );
end;

procedure TTests.TestCase3;
begin
  Assert.AreEqual(
    web3.eth.ens.namehash('foo.eth').ToLower,
    '0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f'
  );
end;

procedure TTests.TestCase4;
begin
  Assert.AreEqual(
    web3.eth.ens.namehash('alice.eth').ToLower,
    '0x787192fc5378cc32aa956ddfdedbf26b24e8d78e40109add0eea2c1a012c3dec'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
