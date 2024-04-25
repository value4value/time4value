# Mest Protocol

<p align="center">
  <br/>
  Mest is a payment protocol for everyone.
  <br/>
  Buy something via the bonding curve and yield farming.
  <br/><br/>
</p>

Mest Protocol provides a new way to pay where you can stake ETH by a unique S-shaped bonding curve and yield farming, buy what you need, and withdraw whenever you want. 
* 🐦 For users, pay early and save more
* 💵 For you, long-term revenue from fees and yield
* ⚡ Lightweight, S-curve, and flexible yield strategies

| Features                       | Mest | Friendtech | Coinbase Commerce |
|--------------------------------|------|------------|-------------------|
| User Capacity                  | 100K | <= 100     | N/A               |
| Capital efficiency             | ✅    | ❌          | ❌               |
| Permissionless                 | ✅    | ✅          | ❌               |
| Tokenization                   | ✅    | ❌          | ❌               |


## How Mest works？

### Buy / Sell

Mest Protocol is an S-shaped bonding curve that combines a quadratic function and a square root function. Briefly, when you buy, mint tokens and the price gradually rises; when you sell, burn tokens and the price gradually falls. The staked ETH will be deposited into the interest rate market, which provides the creator with a sustainable income, while at the same time you can enjoy the services provided by the creator through NFT.

Note: A 5% commission is paid to the creator for each transaction, as well as an optional protocol fee.


### Claim

Mest Protocol deposits funds into an interest rate market (e.g. Aave / Pendle.) and the pool will hold equity tokens like aToken / PT. Users can withdraw the corresponding ETH at any time by burn NFTs, while the creator only claims the interest, i.e. the amount that exceeds the pledged assets.

## Contract
We detail a few of the core contracts in the Mest protocol.

### MestERC1155

MestERC1155 is a standard ERC1155 contract where the NFTs are used as shares for the boding curve, i.e. the ownership share of the pool, and every time a buy / sell shares is made the respective amount of NFTs is minted / burned.

### MestShares

MestShares is the core contract that contains the S-Curve and is responsible to create, mint, and burn shares, as well as to choose the yield strategy and claim the yield through MestYield.

### MestYield 

MestYield is the yield strategy contract. It is a upgradeable proxy contract, which is responsible for the deposit and withdrawal of funds in the interest rate market, and calculates the yield that can be claimed.

## Deployment And Test

We use foundry and hardhat to build tests and deploy.

### Commands

```bash
Scripts available via `npm run-script`:
  compile
    npx hardhat compile
  deploy
    npx hardhat run scripts/deploy.ts
  verify
    npx hardhat verify
```

```bash
Foundry Commands
  unit tests
    forge test --fork-url [ARB-RPC]
  coverage
    forge coverage --fork-url [ARB-RPC]
```