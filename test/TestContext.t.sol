// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { MestSharesFactoryV1 } from "contracts/core/MestSharesFactoryV1.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MestERC1155 } from "contracts/core/MestERC1155.sol";
import { IAavePool } from "contracts/interface/IAave.sol";

contract TestContext is Test {
    MestSharesFactoryV1 public sharesFactory;
    MestERC1155 public sharesNFT;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;

    address public receiver = address(999);
    address public owner = address(1);

    /**
     * @dev belows are the related token/contract address on optimism mainnet.
     *      for other chain/testnet please replace with the correct address.
     *
     *      for POOL, WETH_GATEWAY checkout https://github.com/bgd-labs/aave-address-book/blob/main/src/AaveV3Arbitrum.sol
     *      POOL -> aavePool
     *      WETH_GATEWAY -> aaveGateway
     *
     *      for WETH
     *      checkout https://api.coingecko.com/api/v3/coins/weth and find address in correct platform
     */
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant AAVE_WETH_GATEWAY = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;
    // Speed up time to claim yield
    // 2029-11-01 00:00:30
    uint256 public constant YIELD_CLAIM_TIME = 1930488030;

    // aTokenAddress: associated token address
    IERC20 public aWETH = IERC20(IAavePool(AAVE_POOL).getReserveData(WETH).aTokenAddress);

    string public constant BASE_URI = "https://mest.io/shares/";
    uint256 public constant BASE_PRICE = 5000000000000000; // 0.005 ETH as base price
    uint256 public constant INFLECTION_POINT = 1500;
    uint256 public constant INFLECTION_PRICE = 102500000000000000;
    uint256 public constant LINEAR_PRICE_SLOPE = 0;

    function createMestFactory() public {
        sharesNFT = new MestERC1155(BASE_URI);

        sharesFactory = new MestSharesFactoryV1(
            address(sharesNFT),
            BASE_PRICE, // basePrice,
            INFLECTION_POINT, // inflectionPoint,
            INFLECTION_PRICE, // inflectionPrice
            LINEAR_PRICE_SLOPE // linearPriceSlope,
        );

        aaveYieldAggregator = new AaveYieldAggregator(address(sharesFactory), WETH, AAVE_POOL, AAVE_WETH_GATEWAY);
        blankYieldAggregator = new BlankYieldAggregator(address(sharesFactory), WETH);

        sharesNFT.setFactory(address(sharesFactory));
        sharesNFT.transferOwnership(owner);
        sharesFactory.transferOwnership(owner);
        aaveYieldAggregator.transferOwnership(owner);

        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));
    }

    function testSuccess() public {}
}
