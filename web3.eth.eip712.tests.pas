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
    [Test]
    procedure TestTypedDataHash;
    [Test]
    procedure TestChallengeHash;
    [Test]
    procedure TestSignature;
    [Test]
    procedure TestComplexType;
  end;

implementation

uses
  // web3
  web3.eth.eip712,
  web3.eth.types,
  web3.utils;

procedure TTests.TestDomainSeparator; // test the ParaSwap domain
begin
  const typedData = TTypedData.Create;
  try
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

procedure TTests.TestTypedDataHash; // sell 0.005 WETH for USDT at $10k on ParaSwap
begin
  const typedData = TTypedData.Create;
  try
    typedData.Types.Add('Order', [
      TType.Create('expiry',       'int256'),
      TType.Create('nonceAndMeta', 'string'),
      TType.Create('maker',        'string'),
      TType.Create('taker',        'string'),
      TType.Create('makerAsset',   'string'),
      TType.Create('takerAsset',   'string'),
      TType.Create('makerAmount',  'string'),
      TType.Create('takerAmount',  'string')
    ]);

    typedData.PrimaryType := 'Order';

    typedData.Message.Add('expiry',       0);
    typedData.Message.Add('nonceAndMeta', '26307029471956252527666326988893094353806785773568');
    typedData.Message.Add('maker',        '0xA5e63fe2e1C231957cD524416c7618D9BC690db0'); // owner
    typedData.Message.Add('taker',        '0x0000000000000000000000000000000000000000'); // anyone
    typedData.Message.Add('makerAsset',   '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'); // WETH
    typedData.Message.Add('takerAsset',   '0xdAC17F958D2ee523a2206206994597C13D831ec7'); // USDT
    typedData.Message.Add('makerAmount',  '5000000000000000');
    typedData.Message.Add('takerAmount',  '50000000');

    const typedDataHash = typedData.HashStruct(typedData.PrimaryType, typedData.Message, [vaTypes, vaPrimaryType]);
    if typedDataHash.isErr then
      Assert.Fail(typedDataHash.Error.Message)
    else
      Assert.AreEqual('0xF9E9C453CD1DFA2FAE411C4B2D41B9912B2E7450C05EE5AB83FF9600EE31A440', web3.utils.toHex(typedDataHash.Value));
  finally
    typedData.Free;
  end;
end;

procedure TTests.TestChallengeHash; // put everything together and prepare the data for signing
begin
  const typedData = TTypedData.Create;
  try
    typedData.Types.Add('Order', [
      TType.Create('expiry',       'int256'),
      TType.Create('nonceAndMeta', 'string'),
      TType.Create('maker',        'string'),
      TType.Create('taker',        'string'),
      TType.Create('makerAsset',   'string'),
      TType.Create('takerAsset',   'string'),
      TType.Create('makerAmount',  'string'),
      TType.Create('takerAmount',  'string')
    ]);

    typedData.PrimaryType := 'Order';

    typedData.Domain.Name              := 'AUGUSTUS RFQ';
    typedData.Domain.Version           := '1';
    typedData.Domain.ChainId           := 1;
    typedData.Domain.VerifyingContract := '0xe92b586627cca7a83dc919cc7127196d70f55a06';

    typedData.Message.Add('expiry',       0);
    typedData.Message.Add('nonceAndMeta', '26307029471956252527666326988893094353806785773568');
    typedData.Message.Add('maker',        '0xA5e63fe2e1C231957cD524416c7618D9BC690db0'); // owner
    typedData.Message.Add('taker',        '0x0000000000000000000000000000000000000000'); // anyone
    typedData.Message.Add('makerAsset',   '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'); // WETH
    typedData.Message.Add('takerAsset',   '0xdAC17F958D2ee523a2206206994597C13D831ec7'); // USDT
    typedData.Message.Add('makerAmount',  '5000000000000000');
    typedData.Message.Add('takerAmount',  '50000000');

    const challengeHash = typedData.ChallengeHash;
    if challengeHash.isErr then
      Assert.Fail(challengeHash.Error.Message)
    else
      Assert.AreEqual('0x93AD2AC991EB36F2152EBEA3D541D6810CD2653831A3BBC1466FCE96F4BD10B7', web3.utils.toHex(challengeHash.Value));
  finally
    typedData.Free;
  end;
end;

procedure TTests.TestSignature; // prepare the data for signing and sign the challenge hash
begin
  const typedData = TTypedData.Create;
  try
    typedData.Types.Add('Order', [
      TType.Create('expiry',       'int256'),
      TType.Create('nonceAndMeta', 'string'),
      TType.Create('maker',        'string'),
      TType.Create('taker',        'string'),
      TType.Create('makerAsset',   'string'),
      TType.Create('takerAsset',   'string'),
      TType.Create('makerAmount',  'string'),
      TType.Create('takerAmount',  'string')
    ]);

    typedData.PrimaryType := 'Order';

    typedData.Domain.Name              := 'AUGUSTUS RFQ';
    typedData.Domain.Version           := '1';
    typedData.Domain.ChainId           := 1;
    typedData.Domain.VerifyingContract := '0xe92b586627cca7a83dc919cc7127196d70f55a06';

    typedData.Message.Add('expiry',       0);
    typedData.Message.Add('nonceAndMeta', '26307029471956252527666326988893094353806785773568');
    typedData.Message.Add('maker',        '0xA5e63fe2e1C231957cD524416c7618D9BC690db0'); // owner
    typedData.Message.Add('taker',        '0x0000000000000000000000000000000000000000'); // anyone
    typedData.Message.Add('makerAsset',   '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'); // WETH
    typedData.Message.Add('takerAsset',   '0xdAC17F958D2ee523a2206206994597C13D831ec7'); // USDT
    typedData.Message.Add('makerAmount',  '5000000000000000');
    typedData.Message.Add('takerAmount',  '50000000');

    const challengeHash = typedData.ChallengeHash;
    if challengeHash.isErr then
    begin
      Assert.Fail(challengeHash.Error.Message);
      EXIT;
    end;

    const signature = web3.eth.eip712.sign(TPrivateKey('8994250F00DB3D85A260D8FDCF2152063938C1F57005928AA7B964197BCC8830'), challengeHash.Value);
    if signature.isErr then
      Assert.Fail(signature.Error.Message)
    else
      Assert.AreEqual('0xCED8AA0840029658CC59E51DC25CB2D7BD52AB68B5F6572D882E909532245F4376A5ADC60599A29D274DA2A5E21186F94A80A9A7A479F094E32380A89EFDC5A51C', signature.Value.ToHex);
  finally
    typedData.Free;
  end;
end;

procedure TTests.TestComplexType;
begin
  const
    typedData = TTypedData.Create;
  try
    typedData.types.Add('Person', [
      TType.Create('name', 'string'),
      TType.Create('wallet', 'address')]);

    typedData.types.Add('Mail', [
    TType.Create('from', 'Person'),
      TType.Create('to', 'Person'),
      TType.Create('contents', 'string')]);

    typedData.PrimaryType := 'Mail';
    typedData.Domain.Name := 'Ether Mail';
    typedData.Domain.Version := '1';
    typedData.Domain.ChainId := 1;
    typedData.Domain.VerifyingContract := '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC';
    const msgfrom = newTypedMessage;
    msgfrom.Add('name', 'Cow');
    msgfrom.Add('wallet', '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826');
    typedData.Message.Add('from', msgfrom);

    const msgto = newTypedMessage;
    msgto.Add('name', 'Bob');
    msgto.Add('wallet', '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB');
    typedData.Message.Add('to', msgto);
    typedData.Message.Add('contents', 'Hello, Bob!');
    const challengeHash = typedData.challengeHash;
    if challengeHash.isErr then
    begin
      Assert.Fail(challengeHash.Error.Message);
      EXIT;
    end else
      Assert.AreEqual('0xBE609AEE343FB3C4B28E1DF9E632FCA64FCFAEDE20F02E86244EFDDF30957BD2',
        web3.utils.toHex(challengeHash.Value));
    const
      signature = web3.eth.eip712.sign(TPrivateKey('83f8964bd55c98a4806a7b100bd9d885798d7f936f598b88916e11bade576204'),
        challengeHash.Value);

    if signature.isErr then
      Assert.Fail(signature.Error.Message)
    else
      Assert.AreEqual('0xF714D2CD123498A5551CAFEE538D073C139C5C237C2D0A98937A5CCE109BFEFB7C6585FED974543C649B0CAE34AC8763EE0AC536A56A82980C14470F0029907B1B', signature.Value.toHex);
  finally
    typedData.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTests);

end.
