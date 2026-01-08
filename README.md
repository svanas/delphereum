## What is Delphereum?

Delphereum is a Delphi interface to the Ethereum blockchain that allows for development of native dapps (aka decentralized applications) that interact with the Ethereum network, including sending transactions, working with smart contracts, and reading blockchain data.

## What is Delphi?

[Delphi](https://www.embarcadero.com/products/delphi) is a development environment that compiles into native apps for Windows, macOS, iOS, and Android.

## What is Ethereum?

[Ethereum](https://www.ethereum.org/) is a blockchain-based distributed computing platform and operating system featuring smart contracts.

## What is a smart contract?

A smart contract is a computation that takes place on a blockchain or distributed ledger. You can think of a smart contract as a microservice that runs trustless on the backend of your application.

Smart contracts can have many applications, ranging from sports betting to online voting. But the true power of smart contracts is in managing assets that have value and are scarce.

Once added to the blockchain, a smart contract becomes public and cannot be modified or removed. This assures your users that the rules are transparent and will never change.

## What is a dapp?

A [dapp](https://en.wikipedia.org/wiki/Decentralized_application) is an application whose backend runs on a decentralised network with trustless protocols. Dapps aren’t owned by anyone, cannot be shut down, and have zero downtime.

## What other networks does this thing support?

Delphereum supports [every EVM-compatible network](https://chainlist.org/), including (but not limited to)
* [Arbitrum](https://arbitrum.io/)
* [Optimism](https://optimism.io/)
* [Polygon](https://polygon.technology/)
* [Gnosis](https://www.gnosischain.com/)
* [BNB Chain](https://www.bnbchain.org/)
* [Fantom](https://fantom.foundation/)
* [PulseChain](https://pulsechain.com/)

## Dependencies

Before you can compile this project, you will need to clone the following repositories, and then add them to your Delphi search path:
```
git clone https://github.com/rvelthuis/DelphiBigNumbers
git clone https://github.com/Xor-el/SimpleBaseLib4Pascal
git clone https://github.com/Xor-el/HashLib4Pascal
git clone https://github.com/Xor-el/CryptoLib4Pascal
```
Please note there are NO runtime dependencies. Delphereum is lightweight and self-contained.

## Search path

Assuming your project is named `MyProject` and you have a projects directory with this structure...

```
MyProject 
CryptoLib4Pascal
delphereum
DelphiBigNumbers
HashLib4Pascal
SimpleBaseLib4Pascal
```

...then this is your Delphi search path:

```
../delphereum;../DelphiBigNumbers/Source;../CryptoLib4Pascal/CryptoLib/src/Interfaces;../CryptoLib4Pascal/CryptoLib/src/Math;../CryptoLib4Pascal/CryptoLib/src/Utils;../CryptoLib4Pascal/CryptoLib/src/Security;../HashLib4Pascal/HashLib/src/Interfaces;../HashLib4Pascal/HashLib/src/Utils;../CryptoLib4Pascal/CryptoLib/src/Utils/Randoms;../HashLib4Pascal/HashLib/src/Base;../HashLib4Pascal/HashLib/src/KDF;../HashLib4Pascal/HashLib/src/Nullable;../HashLib4Pascal/HashLib/src/NullDigest;../HashLib4Pascal/HashLib/src/Checksum;../HashLib4Pascal/HashLib/src/Hash32;../HashLib4Pascal/HashLib/src/Hash64;../HashLib4Pascal/HashLib/src/Hash128;../HashLib4Pascal/HashLib/src/Crypto;../HashLib4Pascal/HashLib/src/Interfaces/IBlake2BParams;../HashLib4Pascal/HashLib/src/Crypto/Blake2BParams;../HashLib4Pascal/HashLib/src/Interfaces/IBlake2SParams;../HashLib4Pascal/HashLib/src/Crypto/Blake2SParams;../CryptoLib4Pascal/CryptoLib/src/Crypto/Digests;../CryptoLib4Pascal/CryptoLib/src/Asn1/Pkcs;../CryptoLib4Pascal/CryptoLib/src/Asn1;../CryptoLib4Pascal/CryptoLib/src/Utils/Encoders;../SimpleBaseLib4Pascal/SimpleBaseLib/src/Bases;../SimpleBaseLib4Pascal/SimpleBaseLib/src/Utils;../SimpleBaseLib4Pascal/SimpleBaseLib/src/Interfaces;../CryptoLib4Pascal/CryptoLib/src/Asn1/RossStandart;../CryptoLib4Pascal/CryptoLib/src/Asn1/Oiw;../CryptoLib4Pascal/CryptoLib/src/Asn1/Nist;../CryptoLib4Pascal/CryptoLib/src/Asn1/Misc;../CryptoLib4Pascal/CryptoLib/src/Asn1/TeleTrust;../CryptoLib4Pascal/CryptoLib/src/Asn1/CryptoPro;../CryptoLib4Pascal/CryptoLib/src/Crypto/Prng;../CryptoLib4Pascal/CryptoLib/src/Utils/Rng;../CryptoLib4Pascal/CryptoLib/src/Crypto/Engines;../CryptoLib4Pascal/CryptoLib/src/Crypto/Parameters;../CryptoLib4Pascal/CryptoLib/src/Crypto;../CryptoLib4Pascal/CryptoLib/src/Math/EC;../CryptoLib4Pascal/CryptoLib/src/Crypto/EC;../CryptoLib4Pascal/CryptoLib/src/Math/EC/Endo;../CryptoLib4Pascal/CryptoLib/src/Asn1/Sec;../CryptoLib4Pascal/CryptoLib/src/Asn1/X9;../CryptoLib4Pascal/CryptoLib/src/Asn1/CryptLib;../CryptoLib4Pascal/CryptoLib/src/Math/Raw;../CryptoLib4Pascal/CryptoLib/src/Math/EC/Multiplier;../CryptoLib4Pascal/CryptoLib/src/Math/EC/Abc;../CryptoLib4Pascal/CryptoLib/src/Math/Field;../CryptoLib4Pascal/CryptoLib/src/Math/EC/Custom/Sec;../CryptoLib4Pascal/CryptoLib/src/Math/EC/Custom/Djb;../CryptoLib4Pascal/CryptoLib/src/Crypto/Signers;../CryptoLib4Pascal/CryptoLib/src/Crypto/Generators;../CryptoLib4Pascal/CryptoLib/src/Crypto/Macs
```

## Tutorials

1. [Connecting Delphi to a local (in-memory) blockchain](https://medium.com/@svanas/connecting-delphi-to-a-local-in-memory-blockchain-9a1512d6c5b0)
2. [Connecting Delphi to the Ethereum main net](https://medium.com/@svanas/connecting-delphi-to-the-ethereum-main-net-5faf1feffd83)
3. [Connecting Delphi to smart contracts](https://medium.com/@svanas/connecting-delphi-to-smart-contracts-3146b12803a1)
4. [Generating an Ethereum-signed message signature in Delphi](https://medium.com/@svanas/generating-an-ethereum-signed-message-signature-in-delphi-75661ce5031b)
5. [Transferring ether with Delphi](https://medium.com/@svanas/transferring-ether-with-delphi-b5f24b1a98a4)
6. [Transferring ERC-20 tokens with Delphi](https://medium.com/@svanas/transferring-erc-20-tokens-with-delphi-bb44c05b295d)
7. [Delphi and Ethereum Name Service (ENS)](https://medium.com/@svanas/delphi-and-ethereum-name-service-ens-4443cd278af7)
8. [A 3-minute Smart Contract and Delphi - Part 1](https://medium.com/@svanas/a-3-minute-smart-contract-and-delphi-61d998571d)
9. [A 3-minute Smart Contract and Delphi - Part 2](https://medium.com/@svanas/a-3-minute-smart-contract-and-delphi-part-2-446925faa47b)
10. [QuikNode, Ethereum and Delphi](https://medium.com/@svanas/quiknode-ethereum-and-delphi-f7bfc9671c23)
11. [Delphi and the Ethereum Dark Forest](https://svanas.medium.com/delphi-and-the-ethereum-dark-forest-5b430da3ad93)
12. [Swap one token for another in Delphi](https://svanas.medium.com/swap-one-token-for-another-in-delphi-bcb999c47f7)

## Videos

If you are confused about what Ethereum and smart contracts and dapps (aka decentralized apps) are, watch this 3-part presentation from Ethereum DevCon in 2015:

1. https://www.youtube.com/watch?v=seU7DykOxfc
2. https://www.youtube.com/watch?v=nPpi9BPkRbo
3. https://www.youtube.com/watch?v=Ij5tGo8cp80

While Mist doesn’t exist anymore (it has been replaced with your favorite web browser plus [MetaMask](https://metamask.io/) or any other crypto wallet such as [Rabby](https://rabby.io/) or [Phantom](https://phantom.com/)), the above videos explain the principles behind Ethereum and smart contracts and the decentralized web pretty good.

## Case studies

### 1. Migratooor

[Migratooor](https://github.com/svanas/migratooor#readme) transfers all your tokens from one wallet to another. You can download migratooor for [Windows](https://github.com/svanas/migratooor/releases/latest/download/Windows.zip) or [macOS](https://github.com/svanas/migratooor/releases/latest/download/macOS.zip).

### 2. Bankless

[Bankless](https://github.com/svanas/bankless#readme) is a DeFi desktop app with the highest possible yield on your stablecoin savings.

Made with Delphi, bankless is a small and simple dapp that makes it super easy to transfer your savings from one lending protocol to another with the click of one button.

You can download bankless for [Windows](https://github.com/svanas/bankless/releases/latest/download/Windows.zip) or [macOS](https://github.com/svanas/bankless/releases/latest/download/macOS.zip).

### 3. Balancer

[Balancer](https://github.com/svanas/balancer) is an implementation of the https://balancer.finance protocol in native code, made possible by an awesome grant from the Balancer DAO. You can download balancer for [Windows](https://github.com/svanas/balancer/releases/latest/download/Windows.zip) or [macOS](https://github.com/svanas/balancer/releases/latest/download/macOS.zip).

### 4. PubSub

[PubSub](https://github.com/svanas/PubSub) is a simple "Hello World" example project, demonstrating how to subscribe to an Ethereum RPC provider and get notified every time a new block got mined. You can download PubSub [for Windows](https://github.com/svanas/PubSub/releases/latest/download/Windows.zip).

## License

Distributed under the [GNU AGP v3.0](https://github.com/svanas/delphereum/blob/master/LICENSE) with [Commons Clause](https://commonsclause.com/) license.

## Sponsors

* [eSeGeCe WebSockets](https://www.esegece.com/websockets)
* [IPWorks WebSockets](https://www.nsoftware.com/ipworks/ws/)
* [Blocknative Mempool Explorer](https://www.blocknative.com/explorer)
* [Balancer Grants DAO](https://medium.com/@BalancerGrants/stefan-is-adding-balancer-to-delphereum-with-its-newest-grant-c0f646c9d2de)

## Commercial support and training

Commercial support and training is available from [Stefan](https://devstory.fyi/svanas).
