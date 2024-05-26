// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import { BaseScript } from "./Base.s.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";

contract DeployScript is BaseScript {
    SharesFactoryV1 public sharesFactory;
    SharesERC1155 public sharesNFT;
    BlankYieldAggregator public blankYieldAggregator;

    string public constant BASE_URI = "https://vv.meme/shares/uri/";
    uint96 public constant BASE_PRICE = 0.005 ether;
    uint32 public constant INFLECTION_POINT = 1500;
    uint128 public constant INFLECTION_PRICE = 0.1025 ether;
    uint128 public constant LINEAR_PRICE_SLOPE = 0;

    function run() public virtual broadcast() {
        require(WETH[block.chainid] != address(0), "WETH not set");

        sharesNFT = new SharesERC1155(BASE_URI);
        sharesFactory = new SharesFactoryV1(address(sharesNFT), BASE_PRICE, INFLECTION_POINT, INFLECTION_PRICE, LINEAR_PRICE_SLOPE);
        blankYieldAggregator = new BlankYieldAggregator(address(sharesFactory), WETH[block.chainid]);
        
        // initialize
        sharesFactory.resetYield(address(blankYieldAggregator));
        sharesNFT.setFactory(address(sharesFactory));

        // ownership
        sharesNFT.transferOwnership(OWNER);

        /*
         ********************************************************************************
         * Mauunal steps to be executed after deploying this script
         ********************************************************************************
         */

        // Note: Transfer sharesFactory ownership with 2-step process
        // sharesFactory.transferOwnership(owner);
        // vm.prank(owner);
        // sharesFactory.acceptOwnership();
    }
}
