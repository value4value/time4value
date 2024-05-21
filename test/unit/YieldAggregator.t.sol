// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { console } from "forge-std/console.sol";
import { BaseTest } from "../BaseTest.t.sol";

contract YieldAggregatorTests is BaseTest {
    uint256 public defaultYieldBuffer = 1e12;

    function setUp() public {
        createFactory();
    }

    function test_migrateNewYieldAggregator() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        sharesFactory.migrate(address(0));

        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));
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
        // Mock eth balance, and call yieldDeposit
        vm.deal(address(aaveYieldAggregator), 10 ether);
        vm.prank(address(sharesFactory));
        aaveYieldAggregator.yieldDeposit();
        assertTrue(aWETH.balanceOf(address(sharesFactory)) == 10 ether);
        assertTrue(address(aaveYieldAggregator).balance == 0);

        // Migrate to BlankYieldAggregator
        // Mock eth balance, and call yieldDeposit
        vm.prank(owner);
        sharesFactory.migrate(address(blankYieldAggregator));
        vm.deal(address(blankYieldAggregator), 10 ether);
        vm.prank(address(sharesFactory));
        blankYieldAggregator.yieldDeposit();
        assertTrue(address(sharesFactory).balance == 20 ether);
        assertTrue(address(blankYieldAggregator).balance == 0);

        vm.expectRevert(bytes("Only factory"));
        aaveYieldAggregator.yieldDeposit();
    }

    function test_yieldWithdraw() public {
        // Sell shares
        // Claim yield
        // Migrate YieldAggregator
        // Check aWETH / ETH balance
    }

    function test_yieldBalanceOf() public {

    }

    function test_yieldToken() public {

    }

    function test_yieldMaxClaimable() public {

    }

    function _testBuyShares() public {
        uint256 aliceBalBefore = addrAlice.balance;
        uint256 bobBalBefore = addrBob.balance;
        uint256 referrerBalBefore = referralReceiver.balance;
        // uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountBefore = sharesFactory.depositedETHAmount();

        vm.deal(addrBob, 10 ether);
        _buyShare(addrBob, 0, 2, referralReceiver);

        uint256 aliceBalAfter = addrAlice.balance;
        uint256 bobBalAfter = addrBob.balance;
        uint256 referrerBalAfter = referralReceiver.balance;
        // uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountAfter = sharesFactory.depositedETHAmount();

        assertEq(bobBalBefore - bobBalAfter, 5500450999999993); // Bob buy 1 share
        assertEq(aliceBalAfter - aliceBalBefore, 250020499999999); // Alice receive creator fee
        assertEq(referrerBalAfter - referrerBalBefore, 250020499999999); // referral receive fee
        // assertEq(factoryBalAfter - factoryBalBefore, 5000409999999995); // Factory aWETH balance with rounding error
        assertEq(depositedETHAmountAfter - depositedETHAmountBefore, 5000409999999995); // Factory records ETH Amount

        uint256 bobShareBal = sharesNFT.balanceOf(addrBob, 0);
        assertEq(bobShareBal, 2);
    }

    function _buyShare(address sender, uint256 shareId, uint32 quantity, address referral) internal {
        (uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(shareId, quantity, referral);
        vm.prank(address(sender));
        sharesFactory.buyShare{ value: buyPriceAfterFee }(shareId, quantity, referral);
    }
}
