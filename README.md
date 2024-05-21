<samp>
  <sub><em>Value4Value</em></sub>

  <div align="center">
    <br />
    <em>A NEW WAY TO PAY.</em> <br />
    <em>Payment via the bonding curve and yield farming.</em>
    <br />
  </div>
</samp>

##

**A payment protocol designed for creators**, it bridges the gap between creators and fans, where fans can **donate, sponsor, subscribe**, and more, while creators receive **fees and yield**.

- For fans, pay early and earn more;
- For creators, long-term income from fees and yield;
- Lightweight with flexible curve and yield strategies;
- No protocol fee, any client can be charged via referral fee;
- Stake what you need, and withdraw when you want;
- Made for creators like startups, indie hackers and KOLs.

## How it works？

The contract uses a sigmoid bonding curve for dynamic pricing. When you buy, it mints tokens and drives prices up, then when you sell, it burns tokens and drives prices down. The staked ETH is allocated in an interest-rate market to generate sustainable rewards, which are then redistributed to the creators.

<div align="center">
  <img src="images/curve.gif" width="80%">
</div>

## Why it is better?
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

> The token is a standard ERC1155 contract, with NFTs acting as shares in the bonding curve. When you trade shares, NFTs are minted or burned.

| Network          | Address                                    |
|------------------|--------------------------------------------|
| Optimism Mainnet | N/A                                        |
| Optimism Sepolia | 0x07cB2490DfBFd63613318F87156D935ddAcb62F4 |

### Shares

> SharesFactory is the core contract that contains the bonding curve and yield aggregator logic where you can mint, buy, and sell shares, as well as change yield strategies and claim yields.

| Network          | Address                                    |
|------------------|--------------------------------------------|
| Optimism Mainnet | N/A                                        |
| Optimism Sepolia | 0x5F31921A68eA5b350baF141536933Cc7d70EBAEa |

### Yield

> YieldAggregator is a yield strategy contract that provides a common interface for SharesFactory to use, such as deposit, withdraw, and claimable. However, the underlying logic can be any yield strategy, such as Aave, Pendle and LRT, or nothing at all.

| Network          | Address                                    |
|------------------|--------------------------------------------|
| Optimism Mainnet | N/A                                        |
| Optimism Sepolia | 0x2c1414c3F442AA7a4E531E2891009Dd1a8744b59 |

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

Thanks to [Simon de la Rouviere](https://docs.google.com/document/d/1VNkBjjGhcZUV9CyC0ccWYbqeOoVKT2maqX0rK3yXB20), whose ideas inspired *V4V* to combine curated market with bonding curves, and to the ideal S-curve model from [sound protocol](https://github.com/soundxyz/sound-protocol), we’ve also learned the principle of minimalism from [friend tech](https://www.friend.tech) and [bodhi](https://bodhi.wtf).
