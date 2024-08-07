<samp>
  <sub><em>Time4Value</em></sub>

  <div align="center">
    <br />
    A NEW WAY TO PAY. <br />
    Payment via the bonding curve and yield farming. <br />
    Sell your cryptocurrency time, and buy something with value. <br />
  </div>
</samp>

##

**A payment protocol designed for creators**, it bridges the gap between creators and fans, where fans can **donate,
sponsor, subscribe**, and more, while creators receive **fees and yield**.

- For fans, pay early and earn more;
- For creators, long-term income from fees and yield;
- Lightweight with flexible curve and yield strategies;
- No protocol fee, any client can be charged via referral fee;
- Stake what you need, and withdraw when you want;
- Made for creators like startups, indie hackers and KOLs.

## Bug Bounty

If you are interested in the smart contracts, here's a simple bug bounty:

- Discover [hign / medium](https://docs.sherlock.xyz/audit/judging/judging#iv.-how-to-identify-a-high-issue) issues -
  $1200 *cc ashu@vv.meme*
- Add / optimize test cases - $100 / PR

## How it works？

The contract uses a sigmoid bonding curve for dynamic pricing. When you buy, it mints tokens and drives prices up, then
when you sell, it burns tokens and drives prices down. The staked ETH is allocated in an interest-rate market to
generate sustainable rewards, which are then redistributed to the creators.

<div align="center">
  <img alt="curve" src="images/curve.gif" width="80%">
</div>

## Why is it better?

<div align="center">

| Features           | V4V   | Friendtech | Patreon | Coinbase Commerce |
|--------------------|-------|------------|---------|-------------------|
| Flexible strategy  | ★★★★★ | ★★★☆☆      | ★★★☆☆   | ★☆☆☆☆             |
| Capital efficiency | ★★★☆☆ | ★☆☆☆☆      | ★☆☆☆☆   | ★☆☆☆☆             |
| Permissionless     | ★★★★★ | ★★★★★      | ☆☆☆☆☆   | ★★★☆☆             |
| Tokenization       | ★★★★★ | ★★★☆☆      | ☆☆☆☆☆   | ☆☆☆☆☆             |
| Protocol Fee       | ★★★★☆ | ★★☆☆☆      | ★☆☆☆☆   | ★★★☆☆             |

</div>

## Smart Contracts

### NFT

> The token is a standard ERC1155 contract, with NFTs acting as shares in the bonding curve. When you trade shares, NFTs
> are minted or burned.

| Network          | Address                                                                                                                                |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Optimism Mainnet | [0xb4D09212dcF391aEF9d098Fbfc335527Bf52bc4a](https://optimistic.etherscan.io/address/0xb4d09212dcf391aef9d098fbfc335527bf52bc4a)       |
| Optimism Sepolia | [0x6582281f6fb0adb509ffd7d5e7e6ae957cb3e500](https://sepolia-optimism.etherscan.io/address/0x6582281f6fb0adb509ffd7d5e7e6ae957cb3e500) |
| Cyber Mainnet    | N/A                                                                                                                                    |
| Cyber Sepolia    | 0x552d348657fafd661372f5864093dd9555a2ef06                                                                                             |

### Shares

> SharesFactory is the core contract that contains the bonding curve and yield aggregator logic where you can mint, buy,
> and sell shares, as well as change yield strategies and claim yields.

| Network          | Address                                                                                                                                |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Optimism Mainnet | [0xc2BDb7510CDD65a1bA7aD9b490033563b24f141F](https://optimistic.etherscan.io/address/0xc2BDb7510CDD65a1bA7aD9b490033563b24f141F)       |
| Optimism Sepolia | [0x1637A51717db3F62f836944FdE09BFA4C673b2D9](https://sepolia-optimism.etherscan.io/address/0x1637A51717db3F62f836944FdE09BFA4C673b2D9) |
| Cyber Mainnet    | N/A                                                                                                                                    |
| Cyber Sepolia    | 0x1b05f188388b49ee9053914d3109119d228060b5                                                                                             |

### Yield

> YieldAggregator is a yield strategy contract that provides a common interface for SharesFactory to use, such as
> deposit, withdraw, and claimable. However, the underlying logic can be any yield strategy, such as Aave, Pendle and
> LRT,
> or nothing at all.

| Network          | Address                                                                                                                                |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Optimism Mainnet | [0xFE51D108EeF116a1fFbDf95C563ed6144fC67530](https://optimistic.etherscan.io/address/0xfe51d108eef116a1ffbdf95c563ed6144fc67530)       |
| Optimism Sepolia | [0x1ac43b6530f86a8b07bca8fe29d37ff3a7d84c5d](https://sepolia-optimism.etherscan.io/address/0x1ac43b6530f86a8b07bca8fe29d37ff3a7d84c5d) |
| Cyber Mainnet    | N/A                                                                                                                                    |
| Cyber Sepolia    | 0xba2553060e90551c797bebd48ee04909606bb04f                                                                                             |

## Test and Deploy

We use foundry to build tests and deploy.

```bash
install
  yarn install
test
  yarn run test
coverage
  yarn run coverage
deploy
  yarn run deploy:testnet
  yarn run deploy:mainnet
```

## Acknowledgement

Thanks to [Simon de la Rouviere](https://docs.google.com/document/d/1VNkBjjGhcZUV9CyC0ccWYbqeOoVKT2maqX0rK3yXB20), whose
ideas inspired *V4V* to combine curated market with bonding curves, and to the ideal S-curve model
from [sound protocol](https://github.com/soundxyz/sound-protocol), we’ve also learned the principle of minimalism
from [friend tech](https://www.friend.tech) and [bodhi](https://bodhi.wtf).
