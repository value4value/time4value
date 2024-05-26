// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import { BaseScript } from "./Base.s.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAavePool } from "contracts/interface/IAave.sol";

contract DeployAaveScript is BaseScript {
    AaveYieldAggregator public aaveYieldAggregator;

    function run() public virtual broadcast {
        require(SHARES_FACTORY[block.chainid] != address(0), "SAHRES_FACTORY not set");
        require(WETH[block.chainid] != address(0), "WETH not set");
        require(AAVE_POOL[block.chainid] != address(0), "AAVE_POOL not set");
        require(AAVE_WETH_GATEWAY[block.chainid] != address(0), "AAVE_WETH_GATEWAY not set");

        if (
            block.chainid == OPTIMISM_MAINNET || 
            block.chainid == OPTIMISM_TESTNET
        ) {
            aaveYieldAggregator = new AaveYieldAggregator(
                SHARES_FACTORY[block.chainid], 
                WETH[block.chainid], 
                AAVE_POOL[block.chainid], 
                AAVE_WETH_GATEWAY[block.chainid]
            );
            aaveYieldAggregator.transferOwnership(OWNER);
        }

        /*
         ********************************************************************************
         * Mauunal steps to be executed after deploying this script
         ********************************************************************************
         */

        // Note: Migrate to AaveYieldAggregator with 3 days delay
        // vm.startPrank(owner);
        // sharesFactory.queueMigrateYield(address(aaveYieldAggregator));
        // vm.warp(block.timestamp + 3 days);
        // sharesFactory.executeMigrateYield();
        // vm.stopPrank();
    }
}
