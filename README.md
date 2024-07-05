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
- Add/optimize test cases - $100 / PR

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
| Optimism Mainnet | N/A                                                                                                                                    |
| Optimism Sepolia | [0x02a04ee779587afbbe7f844180ff760bc5e73039](https://sepolia-optimism.etherscan.io/address/0x02a04ee779587afbbe7f844180ff760bc5e73039) |
| Cyber Mainnet    | N/A                                                                                                                                    |
| Cyber Sepolia    |                                                                                                                                        |

### Shares

> SharesFactory is the core contract that contains the bonding curve and yield aggregator logic where you can mint, buy,
> and sell shares, as well as change yield strategies and claim yields.

| Network          | Address                                                                                                                                |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Optimism Mainnet | N/A                                                                                                                                    |
| Optimism Sepolia | [0x4509932e2f18b622f454cf73fac8069901fbbebc](https://sepolia-optimism.etherscan.io/address/0x4509932e2f18b622f454cf73fac8069901fbbebc) |
| Cyber Mainnet    | N/A                                                                                                                                    |
| Cyber Sepolia    | 0x1b05f188388b49ee9053914d3109119d228060b5                                                                                             |

### Yield

> YieldAggregator is a yield strategy contract that provides a common interface for SharesFactory to use, such as
> deposit, withdraw, and claimable. However, the underlying logic can be any yield strategy, such as Aave, Pendle and
> LRT,
> or nothing at all.

| Network          | Address                                                                                                                                |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Optimism Mainnet | N/A                                                                                                                                    |
| Optimism Sepolia | [0xa77fc72fbb2e7f6c4ba4f97f0f6eeee9f46a2b97](https://sepolia-optimism.etherscan.io/address/0xa77fc72fbb2e7f6c4ba4f97f0f6eeee9f46a2b97) |
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
