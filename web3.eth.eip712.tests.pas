{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2024 Stefan van As <svanas@runbox.com>              }
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

unit web3.eth.eip712.tests;

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
    procedure TestDomainSeparator;
  end;

implementation

uses
  // web3
  web3.eth.eip712,
  web3.utils;

procedure TTests.TestDomainSeparator;
begin
  const typedData = TTypedData.Create;
  try
    // test the ParaSwap domain
    typedData.Domain.Name              := 'AUGUSTUS RFQ';
    typedData.Domain.Version           := '1';
    typedData.Domain.ChainId           := 1;
    typedData.Domain.VerifyingContract := '0xe92b586627cca7a83dc919cc7127196d70f55a06';
    // map domain to ITypedMessage
    const mappedDomain = typedData.Domain.Map;
    // encode the domain data and generate a keccak256 hash
    const domainSeparator = typedData.HashStruct('EIP712Domain', mappedDomain, [vaTypes, vaDomain]);
    if domainSeparator.isErr then
      Assert.Fail(domainSeparator.Error.Message)
    else
      Assert.AreEqual('0x6EF27D2D164CDAAC4EF8BE9CB79EA9F4C11EE76DB3A38D2AA02021B5E5019094', web3.utils.toHex(domainSeparator.Value));
  finally
    typedData.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
