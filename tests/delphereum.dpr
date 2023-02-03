{******************************************************************************}
{                                                                              }
{                                  Delphereum                                  }
{                                                                              }
{             Copyright(c) 2021 Stefan van As <svanas@runbox.com>              }
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

program delphereum;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  web3.bip32 in '..\web3.bip32.pas',
  web3.bip32.tests in '..\web3.bip32.tests.pas',
  web3.bip39 in '..\web3.bip39.pas',
  web3.bip39.tests in '..\web3.bip39.tests.pas',
  web3.bip44 in '..\web3.bip44.pas',
  web3.coincap in '..\web3.coincap.pas',
  web3.crypto in '..\web3.crypto.pas',
  web3.crypto.tests in '..\web3.crypto.tests.pas',
  web3.defillama in '..\web3.defillama.pas',
  web3.error in '..\web3.error.pas',
  web3.eth.aave.v1 in '..\web3.eth.aave.v1.pas',
  web3.eth.aave.v2 in '..\web3.eth.aave.v2.pas',
  web3.eth.abi in '..\web3.eth.abi.pas',
  web3.eth.abi.tests in '..\web3.eth.abi.tests.pas',
  web3.eth.alchemy in '..\web3.eth.alchemy.pas',
  web3.eth.alchemy.api in '..\web3.eth.alchemy.api.pas',
  web3.eth.balancer.v2 in '..\web3.eth.balancer.v2.pas',
  web3.eth.blocknative.mempool in '..\web3.eth.blocknative.mempool.pas',
  web3.eth.blocknative.mempool.sgc in '..\web3.eth.blocknative.mempool.sgc.pas',
  web3.eth.breadcrumbs in '..\web3.eth.breadcrumbs.pas',
  web3.eth.chainlink in '..\web3.eth.chainlink.pas',
  web3.eth.compound in '..\web3.eth.compound.pas',
  web3.eth.contract in '..\web3.eth.contract.pas',
  web3.eth.crypto in '..\web3.eth.crypto.pas',
  web3.eth.crypto.tests in '..\web3.eth.crypto.tests.pas',
  web3.eth.defi in '..\web3.eth.defi.pas',
  web3.eth.dydx in '..\web3.eth.dydx.pas',
  web3.eth.ens in '..\web3.eth.ens.pas',
  web3.eth.ens.tests in '..\web3.eth.ens.tests.pas',
  web3.eth.erc20 in '..\web3.eth.erc20.pas',
  web3.eth.erc721 in '..\web3.eth.erc721.pas',
  web3.eth.erc1155 in '..\web3.eth.erc1155.pas',
  web3.eth.etherscan in '..\web3.eth.etherscan.pas',
  web3.eth.fulcrum in '..\web3.eth.fulcrum.pas',
  web3.eth.gas in '..\web3.eth.gas.pas',
  web3.eth.idle.finance.v4 in '..\web3.eth.idle.finance.v4.pas',
  web3.eth.infura in '..\web3.eth.infura.pas',
  web3.eth.logs in '..\web3.eth.logs.pas',
  web3.eth.mstable.save.v2 in '..\web3.eth.mstable.save.v2.pas',
  web3.eth.nodelist in '..\web3.eth.nodelist.pas',
  web3.eth.opensea in '..\web3.eth.opensea.pas',
  web3.eth.origin.dollar in '..\web3.eth.origin.dollar.pas',
  web3.eth in '..\web3.eth.pas',
  web3.eth.nonce in '..\web3.eth.nonce.pas',
  web3.eth.pubsub in '..\web3.eth.pubsub.pas',
  web3.eth.tokenlists in '..\web3.eth.tokenlists.pas',
  web3.eth.tx in '..\web3.eth.tx.pas',
  web3.eth.tx.tests in '..\web3.eth.tx.tests.pas',
  web3.eth.types in '..\web3.eth.types.pas',
  web3.eth.uniswap.v2 in '..\web3.eth.uniswap.v2.pas',
  web3.eth.utils in '..\web3.eth.utils.pas',
  web3.eth.utils.tests in '..\web3.eth.utils.tests.pas',
  web3.eth.yearn.finance.api in '..\web3.eth.yearn.finance.api.pas',
  web3.eth.yearn.finance in '..\web3.eth.yearn.finance.pas',
  web3.eth.yearn.finance.v2 in '..\web3.eth.yearn.finance.v2.pas',
  web3.eth.yearn.finance.v3 in '..\web3.eth.yearn.finance.v3.pas',
  web3.eth.yearn.vaults.v1 in '..\web3.eth.yearn.vaults.v1.pas',
  web3.eth.yearn.vaults.v2 in '..\web3.eth.yearn.vaults.v2.pas',
  web3.graph in '..\web3.graph.pas',
  web3.http in '..\web3.http.pas',
  web3.ipfs in '..\web3.ipfs.pas',
  web3.json in '..\web3.json.pas',
  web3.json.rpc.https in '..\web3.json.rpc.https.pas',
  web3.json.rpc in '..\web3.json.rpc.pas',
  web3.json.rpc.sgc.websockets in '..\web3.json.rpc.sgc.websockets.pas',
  web3.json.rpc.websockets in '..\web3.json.rpc.websockets.pas',
  web3 in '..\web3.pas',
  web3.rlp in '..\web3.rlp.pas',
  web3.rlp.tests in '..\web3.rlp.tests.pas',
  web3.sync in '..\web3.sync.pas',
  web3.utils in '..\web3.utils.pas';

{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.
