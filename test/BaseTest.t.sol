// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAavePool } from "contracts/interface/IAave.sol";

contract BaseTest is Test {
    SharesFactoryV1 public sharesFactory;
    SharesERC1155 public sharesNFT;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;

    uint8 public defaultCurveType = 0;
    address public owner = makeAddr("owner");
    address public addrAlice = makeAddr("addrAlice");
    address public addrBob = makeAddr("addrBob");
    address public referralReceiver = makeAddr("referralReceiver");
    address public yieldReceiver = makeAddr("yieldReceiver");

    /**
     * @dev Below are the related token/contract addresses on the Optimism mainnet.
     *      For other chains/testnets, please replace them with the correct addresses.
     *
     *      Checkout https://search.onaave.com
     *      POOL -> aavePool
     *      WETH_GATEWAY -> aaveGateway
     */
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant AAVE_WETH_GATEWAY = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;

    // Speed up time to claim yield, 2029-11-01 00:00:30
    uint256 public constant YIELD_CLAIM_TIME = 1930488030;

    // aTokenAddress: associated token address
    IERC20 public aWETH = IERC20(IAavePool(AAVE_POOL).getReserveData(WETH).aTokenAddress);

    string public constant BASE_URI = "https://v4v.com/shares/uri/";
    uint96 public constant BASE_PRICE = 5000000000000000; // 0.005 ETH as base price
    uint32 public constant INFLECTION_POINT = 1500;
    uint128 public constant INFLECTION_PRICE = 102500000000000000;
    uint128 public constant LINEAR_PRICE_SLOPE = 0;

    function createFactory() public {
        sharesNFT = new SharesERC1155(BASE_URI);

        sharesFactory = new SharesFactoryV1(
            address(sharesNFT), 
            BASE_PRICE, 
            INFLECTION_POINT, 
            INFLECTION_PRICE, 
            LINEAR_PRICE_SLOPE
        );

        aaveYieldAggregator = new AaveYieldAggregator(address(sharesFactory), WETH, AAVE_POOL, AAVE_WETH_GATEWAY);
        blankYieldAggregator = new BlankYieldAggregator(address(sharesFactory), WETH);

        sharesNFT.setFactory(address(sharesFactory));
        sharesFactory.migrate(address(aaveYieldAggregator));
        
        sharesNFT.transferOwnership(owner);
        sharesFactory.transferOwnership(owner);
        aaveYieldAggregator.transferOwnership(owner);
    }

    function testSuccess() public { }
}
