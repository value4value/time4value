// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { BaseTest } from "../BaseTest.t.sol";

contract YieldAggregatorTests is BaseTest {
    uint256 public defaultYieldBuffer = 1e12;

    function setUp() public {
        createFactory();
    }

    function test_newAggregator() public {
        AaveYieldAggregator aave = new AaveYieldAggregator(address(sharesFactory), WETH, AAVE_POOL, AAVE_WETH_GATEWAY);
        assertEq(aave.yieldBuffer(), defaultYieldBuffer);
        assertEq(aave.FACTORY(), address(sharesFactory));
        assertEq(aave.WETH(), WETH);
        assertEq(address(aave.AAVE_POOL()), AAVE_POOL);
        assertEq(address(aave.AAVE_WETH_GATEWAY()), AAVE_WETH_GATEWAY);
        assertEq(address(aave.aWETH()), address(aWETH));

        BlankYieldAggregator blank = new BlankYieldAggregator(address(sharesFactory), WETH);
        assertEq(blank.FACTORY(), address(sharesFactory));
        assertEq(blank.WETH(), WETH);
    }

    function test_setYieldBuffer() public {
        vm.prank(owner);
        aaveYieldAggregator.setYieldBuffer(1e11);
        assertEq(aaveYieldAggregator.yieldBuffer(), 1e11);

        vm.prank(addrAlice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        aaveYieldAggregator.setYieldBuffer(1e11);
    }

    function test_yieldDepost() public {
        _depositETH2AaveYieldAggregator(10 ether);
        assertTrue(aWETH.balanceOf(address(sharesFactory)) == 10 ether);
        assertTrue(address(aaveYieldAggregator).balance == 0);

        _migrate2BlankYieldAggregator();
        vm.deal(address(blankYieldAggregator), 10 ether);
        vm.prank(address(sharesFactory));
        blankYieldAggregator.yieldDeposit();
        assertTrue(address(sharesFactory).balance == 20 ether);
        assertTrue(address(blankYieldAggregator).balance == 0);

        vm.expectRevert(bytes("Only factory"));
        aaveYieldAggregator.yieldDeposit();

        vm.expectRevert(bytes("Only factory"));
        blankYieldAggregator.yieldDeposit();
    }

    function test_yieldWithdraw() public {
        _depositETH2AaveYieldAggregator(10 ether);

        vm.prank(address(sharesFactory));
        aaveYieldAggregator.yieldWithdraw(10 ether);
        assertTrue(aWETH.balanceOf(address(sharesFactory)) == 0);
        assertTrue(address(sharesFactory).balance == 10 ether);

        _migrate2BlankYieldAggregator();
        vm.prank(address(sharesFactory));
        blankYieldAggregator.yieldWithdraw(10 ether);
        assertTrue(address(blankYieldAggregator).balance == 0);
        assertTrue(address(sharesFactory).balance == 10 ether);

        vm.expectRevert(bytes("Only factory"));
        aaveYieldAggregator.yieldWithdraw(10 ether);

        vm.expectRevert(bytes("Only factory"));
        blankYieldAggregator.yieldWithdraw(0);
    }

    function test_yieldBalanceOf() public {
        _depositETH2AaveYieldAggregator(10 ether);

        uint256 aaveYieldBalance = aaveYieldAggregator.yieldBalanceOf(address(sharesFactory));
        assertEq(aaveYieldBalance, 10 ether);

        uint256 blankYieldBalance = blankYieldAggregator.yieldBalanceOf(address(sharesFactory));
        assertEq(blankYieldBalance, 0);
    }

    function test_yieldToken() public view {
        address aaveYieldToken = aaveYieldAggregator.yieldToken();
        assertEq(aaveYieldToken, address(aWETH));

        address blankYieldToken = blankYieldAggregator.yieldToken();
        assertEq(blankYieldToken, address(WETH));
    }

    function test_yieldMaxClaimable() public {
        _depositETH2AaveYieldAggregator(10 ether);
        uint256 yieldBuffer = aaveYieldAggregator.yieldBuffer();

        // Initial state, return 0
        uint256 expectedClaimableBefore = 0;
        uint256 actualClaimableBefore = aaveYieldAggregator.yieldMaxClaimable(10 ether);
        assertEq(actualClaimableBefore, expectedClaimableBefore);

        // Mock time to 2029-11-01 00:00:30, return yield
        vm.warp(YIELD_CLAIM_TIME);
        uint256 withdrawableETHAmount = aWETH.balanceOf(address(sharesFactory));
        uint256 expectedClaimableAfter = withdrawableETHAmount - 10 ether - yieldBuffer;
        uint256 actualClaimableAfter = aaveYieldAggregator.yieldMaxClaimable(10 ether);
        assertEq(actualClaimableAfter, expectedClaimableAfter);

        // BlankYieldAggregator always return 0
        assertEq(blankYieldAggregator.yieldMaxClaimable(0), 0);
    }

    function _depositETH2AaveYieldAggregator(uint256 amount) internal {
        vm.deal(address(aaveYieldAggregator), amount);
        vm.prank(address(sharesFactory));
        aaveYieldAggregator.yieldDeposit();
    }

    function _migrate2BlankYieldAggregator() internal {
        vm.prank(owner);
        sharesFactory.migrate(address(blankYieldAggregator));
    }
}
