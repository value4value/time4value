// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "contracts/core/MestSharesFactoryV1.sol";
import "contracts/core/YieldAggregator/AaveYieldAggregator.sol";
import { MestERC1155 } from "contracts/core/MestERC1155.sol";
import { BlankYieldAggregator } from "contracts/core/YieldAggregator/BlankYieldAggregator.sol";

contract TestContext is Test {
    MestSharesFactoryV1 public sharesFactory;
    MestERC1155 public sharesNFT;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;
    IAToken public aWETH;

    address public receiver = address(999);
    address public owner = address(1);
    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public aavePool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public aaveGateway = 0xecD4bd3121F9FD604ffaC631bF6d41ec12f1fafb;

    string public baseURI = "https://mest.io/shares/";

    function createMestFactory() public {

        sharesNFT = new MestERC1155(baseURI);

        sharesFactory = new MestSharesFactoryV1(
            address(sharesNFT), 
            5000000000000000, // basePrice, 
            1500, // linearPriceSlope, 
            102500000000000000, // inflectionPoint, 
            0 // inflectionPrice
        );

        sharesNFT.setFactory(address(sharesFactory));
        sharesNFT.transferOwnership(owner);
        sharesFactory.transferOwnership(owner);

        aaveYieldAggregator = new AaveYieldAggregator(
            address(sharesFactory), 
            weth, 
            aavePool, 
            aaveGateway
        );

        blankYieldAggregator = new BlankYieldAggregator(
            address(sharesFactory), 
            weth
        );

        vm.prank(owner);
        aWETH = IAToken(IAavePool(aavePool).getReserveData(weth).aTokenAddress);
        
        // vm.prank(owner);
        // sharesFactory.migrate(address(aaveYieldAggregator));
    }

    function testSuccess() public {}
}