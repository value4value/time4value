// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "../TestContext.t.sol";
import "./MestShareFactory.t.sol";

contract YieldAggregatorTests is TestContext {
    address public Alice = address(1);
    address public Bob = address(2);
    address public referralReceiver = address(3);
    uint256 public defaultYieldBuffer = 1e12;

    function setUp() public {
        createMestFactory();
    }

    function testMigrateNewYieldAggregator() public  {
        vm.prank(owner);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        sharesFactory.migrate(address(0));

        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));
    }

    function testSetInitialYieldAggregator() public {
        // MestSharesFactoryV1 newsharesFactory;
        // AaveYieldAggregator newYieldAggregator;

        // newsharesFactory = new MestSharesFactoryV1(
        //     address(sharesNFT), 
        //     5000000000000000, 
        //     1500, 
        //     102500000000000000, 
        //     0
        // );
        // newYieldAggregator = new AaveYieldAggregator(
        //     address(newsharesFactory), 
        //     weth, 
        //     0x794a61358D6845594F94dc1DB02A252b5b4814aD, 0xecD4bd3121F9FD604ffaC631bF6d41ec12f1fafb
        // );

        // newsharesFactory.transferOwnership(owner);
        // newYieldAggregator.transferOwnership(owner);
        // vm.prank(owner);
        // sharesNFT.setFactory(address(newsharesFactory));

        // test before set yieldAggregator buy fail
        vm.deal(Alice, 10 ether);
        vm.prank(Alice);
        sharesFactory.createShare(Alice);

        vm.prank(Alice);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        sharesFactory.buyShare{value: 5500050111111109}(0, 1, referralReceiver);

        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));

        vm.prank(Alice);
        sharesFactory.buyShare{value:  5500050111111109}(0, 1, referralReceiver);
        assertEq(aWETH.balanceOf(address(sharesFactory)), 5000045555555555);
    }

    // function testSetYieldBuffer() public {
    //     MestShareFactoryTests sharesFactoryTests = new MestShareFactoryTests();
    //     sharesFactoryTests.testBuyShare();

    //     vm.warp(1714693433); // need to fill a number gt current block.timestamp
    //     uint256 depositedETHAmount = sharesFactory.depositedETHAmount();
    //     uint256 maxYield = aaveYieldAggregator.yieldMaxClaimable(depositedETHAmount);
    //     assertEq(depositedETHAmount, 10000227777777775);

    //     uint256 withdrawableETHAmount = aWETH.balanceOf(address(sharesFactory));
    //     uint256 yieldBuffer = withdrawableETHAmount - depositedETHAmount - maxYield;
    //     assertEq(yieldBuffer, defaultYieldBuffer);

    //     vm.prank(owner);
    //     aaveYieldAggregator.setYieldBuffer(1e11);
    //     uint256 maxYieldAfter = aaveYieldAggregator.yieldMaxClaimable(depositedETHAmount);
    //     assertEq(maxYieldAfter - maxYield, 1e12 - 1e11);
    // }
}