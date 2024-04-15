# Mest Share Contract

Mest Protocol is a decentralized curation protocol. Users can support creators through its unique S-shaped bonding curve.

## Architecture

```
contracts
├── core
│   ├── MestSharesFactoryV1.sol
│   └── token
│       └── MestERC1155.sol
├── intf
│   └── IMestShare.sol
└── lib
    ├── BondingCurveLib.sol
    └── FixedPointMathLib.sol
```





![contract-structure](/readmeImg/contract-structure.png)

### MestERC1155

The MestERC1155 contract is a pure token issuance contract that does not appear in the user interaction process after its initial deployment, with Mest as the owner, providing the owner with the following methods:

- setFactory(), which allows changing the factory address with which it interacts
- setURI(), to change the metadata uri prefix for all shares

Only for shareFactory：

* shareMint(), mint certain amount of shares, used in buyShare procession
* shareBurn(), burn certain amount of shares, used in sellShare procession



### MestShareFactoryV1

The Factory contract interacts directly with users and is the main contract, with Mest as the owner. It is divided into the following two modules for description:

**User interaction:**

- write contract: User operation methods, mainly including the creation, buying, and selling of shares:
  - createShare(), for user creation
  - buyShare(), for users to buy a specified number of specified shares
  - sellShare(), for users to sell a specified number of specified shares
- read contract: Read the prices of buying and selling
  - getBuyPriceAfterFee(), users input the shareId and the quantity they want to buy, and it gives the price the user needs to pay
  - getSellPriceAfterFee(), users input the shareId and the quantity they want to sell, and it gives the amount of ETH the user will receive

**Owner management:**

- setProtocolFeeReceiver(), to set the protocol fee collection address
- setProtocolFeePercent(), to set the protocol fee collection percentage
- setCreatorFeePercent(), to set the creator fee collection percentage



## S Curve

The Mest Protocol uses a combination of quadratic and square root functions to form an S-shaped bonding curve. It can act as an automated market maker for the buying and selling of ERC1155. Simply put, when you buy, coins are minted and the price gradually increases; when you sell, coins are burned and the price gradually decreases. It follows the general laws of development: early users will enjoy rapidly rising prices, thereby promoting viral spread in the early stages. When the number of participants reaches a critical point, it will transition to the square root function area, where price growth will become more gradual, thus providing better price stability.

There is its base type:

![img](/readmeImg/s-curve.png)

In Mest Protocol, we use params below:

```python
data = {
    'base_price': 5000000000000000,
    'linear_price_slope': 0,
    'inflection_point': 1500, 
    'inflection_price': 102500000000000000
}
```

The inflection point of the Mest Protocol is at a supply of 1500. Minting before the supply of 1500 will be priced according to a quadratic function curve, and after surpassing the inflection point, it will enter a more gradual square root curve. For example:

- When the supply of the bonding curve reaches 1000, the selling price will increase by 10 times.
- When the supply of the bonding curve reaches 10000, the selling price will increase by 100 times.



## Deployment And Test

We use foundry and hardhat to build tests and deploy.

### Installation

**Hardhat**

```
npm install` or `yarn
```

**Foundry**

First run the command below to get `foundryup`, the Foundry toolchain installer:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

If you do not want to use the redirect, feel free to manually download the

foundryup installation script from [here](https://raw.githubusercontent.com/gakonst/foundry/master/foundryup/install).

Then, in a new terminal session or after reloading your `PATH`, run it to get

the latest `forge` and `cast` binaries:

```
foundryup
```

Advanced ways to use `foundryup`, and other documentation, can be found in the [foundryup package](./foundryup/README.md). Happy forging!

### Commands

```
Scripts available via `npm run-script`:
  compile
    npx hardhat compile
  deploy
    npx hardhat run scripts/deploy.ts
  verify
    npx hardhat verify
```

```
Foundry Commands
  unit tests
    forge test
  coverage
    forge coverage
```

### Adding dependency

Prefer `npm` packages when available and update the remappings.

**Example**

install:

```
yarn add -D @openzeppelin/contracts
```

remapping:

```
@openzeppelin/contracts=node_modules/@openzeppelin/contracts
```

import:

```
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
```

