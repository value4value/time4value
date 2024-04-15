import * as dotenv from 'dotenv';
dotenv.config();
import { readFileSync } from 'fs';
import * as toml from 'toml';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-gas-reporter';
import 'solidity-coverage';
import { HardhatUserConfig, subtask } from 'hardhat/config';
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names';

// default values here to avoid failures when running hardhat
const RINKEBY_RPC = process.env.RINKEBY_RPC || '1'.repeat(32);
const PRIVATE_KEY = process.env.PRIVATE_KEY || '1'.repeat(64);
const SOLC_DEFAULT = '0.8.16';

// try use forge config
let foundry: any;
try {
  foundry = toml.parse(readFileSync('./foundry.toml').toString());
  foundry.default.solc = foundry.default['solc-version']
    ? foundry.default['solc-version']
    : SOLC_DEFAULT;
} catch (error) {
  foundry = {
    default: {
      solc: SOLC_DEFAULT,
    }
  }
}

// prune forge style tests from hardhat paths
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS)
  .setAction(async (_, __, runSuper) => {
    const paths = await runSuper();
    return paths.filter((p: string) => !p.endsWith('.t.sol'));
  });

const config: HardhatUserConfig = {
  paths: {
    cache: 'cache-hardhat',
    sources: './contracts',
    tests: './integration',
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: { chainId: 1337 },
    rinkeby: {
      url: RINKEBY_RPC,
      accounts: [PRIVATE_KEY],
    }
  },
  solidity: {
    version: foundry.default?.solc || SOLC_DEFAULT,
    settings: {
      optimizer: {
        enabled: foundry.default?.optimizer || true,
        runs: foundry.default?.optimizer_runs || 200,
      },
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 77,
    excludeContracts: ['src/test'],
    // API key for CoinMarketCap. https://pro.coinmarketcap.com/signup
    coinmarketcap: process.env.CMC_KEY ?? '',
  },
  etherscan: {
    // API key for Etherscan. https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY ?? '',
  },
};

export default config;
