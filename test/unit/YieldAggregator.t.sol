// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { TestContext } from "../TestContext.t.sol";
import { IYieldAggregator } from "contracts/interface/IYieldAggregator.sol";

contract YieldAggregatorTests is TestContext {
    uint256 public defaultYieldBuffer = 1e12;
    IYieldAggregator public yieldAggregator;

    function setUp() public {
        createFactory();
        yieldAggregator = sharesFactory.yieldAggregator();
    }

    // Specific for aaveYieldAggregator
    function testSetYieldBuffer() public {
        assertEq(aaveYieldAggregator.yieldBuffer(), defaultYieldBuffer);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        aaveYieldAggregator.setYieldBuffer(1e11);

        vm.prank(owner);
        aaveYieldAggregator.setYieldBuffer(1e11);
        assertEq(aaveYieldAggregator.yieldBuffer(), 1e11);
    }

    // Specific for aaveYieldAggregator
    function testYieldMaxClaimable() public view {
        uint256 depositedETHAmount = sharesFactory.depositedETHAmount();
        assertEq(aaveYieldAggregator.yieldMaxClaimable(depositedETHAmount), 0);
    }

    function testYieldDeposit() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Only factory"));
        yieldAggregator.yieldDeposit();

        vm.prank(address(sharesFactory));
        yieldAggregator.yieldDeposit();
    }

    function testYieldWithdraw() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Only factory"));
        yieldAggregator.yieldWithdraw(0);

        vm.prank(address(sharesFactory));
        yieldAggregator.yieldWithdraw(0);
    }

    function testMigrateNewYieldAggregator() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        sharesFactory.migrate(address(0));

        vm.prank(owner);
        sharesFactory.migrate(address(blankYieldAggregator));
    }
}
