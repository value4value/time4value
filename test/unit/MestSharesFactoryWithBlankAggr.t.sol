// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TestContext } from "../TestContext.t.sol";
import { console } from "forge-std/console.sol";

// TODO: fix this test
contract MestSharesFactoryWithBlankAggr is TestContext {
    address public user1 = address(4);
    address public user2 = address(5);

    function testBalanceAfterMigrate() public {
        vm.skip(true);

        vm.warp(YIELD_CLAIM_TIME); // need to fill a number gt current block.timestamp
        uint256 allEthAmount = aWETH.balanceOf(address(sharesFactory));

        //        vm.prank(owner);
        //        sharesFactory.migrate(address(blankYieldAggregator));
        //
        //        uint256 factoryEthBal = address(sharesFactory).balance;
        //        console.log("all factory eth amount:", factoryEthBal);
        //        assertEq(factoryEthBal, allEthAmount);
    }

    //    function testBlankYieldToolBuyAndSell() public {
    //        {
    //            uint256 user1BalBefore = user1.balance;
    //            uint256 receiverBalBefore = receiver.balance;
    //            uint256 factoryBalBefore = address(sharesFactory).balance;
    //            uint256 user2BalBefore = user2.balance;
    //            vm.prank(user2);
    //            sharesFactory.sellShare(0, 1, 0, receiver);
    //            uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
    //            uint256 shareSupply = sharesNFT.totalSupply(0);
    //            assertEq(user2ShareBal, 0);
    //            assertEq(shareSupply, 1);
    //            uint256 user1BalAfter = user1.balance;
    //            uint256 receiverBalAfter = receiver.balance;
    //            uint256 factoryBalAfter = address(sharesFactory).balance;
    //            uint256 user2BalAfter = user2.balance;
    //
    //            assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220);
    //            assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
    //            assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
    //            assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referralFee
    //        }
    //
    //        {
    //            uint256 user1BalBefore = user1.balance;
    //            uint256 receiverBalBefore = receiver.balance;
    //            uint256 factoryBalBefore = address(sharesFactory).balance;
    //            uint256 user2BalBefore = user2.balance;
    //            vm.prank(user2);
    //            sharesFactory.buyShare{ value: 5501050111111109 }(0, 1, receiver);
    //            uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
    //            uint256 shareSupply = sharesNFT.totalSupply(0);
    //            assertEq(user2ShareBal, 1);
    //            assertEq(shareSupply, 2);
    //            uint256 user1BalAfter = user1.balance;
    //            uint256 receiverBalAfter = receiver.balance;
    //            uint256 factoryBalAfter = address(sharesFactory).balance;
    //            uint256 user2BalAfter = user2.balance;
    //
    //            //console.log(factoryBalAfter - factoryBalBefore);
    //            //console.log(user2BalBefore - user2BalAfter);
    //            //console.log(user1BalAfter - user1BalBefore); // creatorFee
    //            //console.log(receiverBalAfter - receiverBalBefore); // referralFee
    //
    //            assertEq(factoryBalAfter - factoryBalBefore, 5000182222222220);
    //            assertEq(user2BalBefore - user2BalAfter, 5500200444444442); // totalPrice + gasFee
    //            assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
    //            assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referralFee
    //        }
    //
    //        vm.prank(owner);
    //        vm.expectRevert(bytes("Insufficient yield"));
    //        sharesFactory.claimYield(1, receiver);
    //
    //        vm.prank(owner);
    //        sharesFactory.claimYield(0, receiver);
    //
    //        uint256 amount = blankYieldAggregator.yieldBalanceOf(address(this));
    //        assertEq(amount, 0);
    //        amount = blankYieldAggregator.yieldMaxClaimable(0);
    //        assertEq(amount, 0);
    //    }
    //
    //    function testBlankYieldAggregator2AaveYieldAggregator() public {
    //        testBlankYieldToolBuyAndSell();
    //        uint256 allEthAmount = address(sharesFactory).balance;
    //
    //        vm.prank(owner);
    //        sharesFactory.migrate(address(aaveYieldAggregator));
    //        uint256 allEthAmountAfter = aWETH.balanceOf(address(sharesFactory));
    //        assertEq(allEthAmount, allEthAmountAfter);
    //
    //        {
    //            uint256 user1BalBefore = user1.balance;
    //            uint256 receiverBalBefore = receiver.balance;
    //            uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
    //            uint256 user2BalBefore = user2.balance;
    //            vm.prank(user2);
    //            sharesFactory.sellShare(0, 1, 0, receiver);
    //            uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
    //            uint256 shareSupply = sharesNFT.totalSupply(0);
    //            assertEq(user2ShareBal, 0);
    //            assertEq(shareSupply, 1);
    //            uint256 user1BalAfter = user1.balance;
    //            uint256 receiverBalAfter = receiver.balance;
    //            uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
    //            uint256 user2BalAfter = user2.balance;
    //
    //            console.log("factory bal:", factoryBalBefore - factoryBalAfter);
    //            console.log("standardAmount:", 5000182222222220);
    //            assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
    //            assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
    //            assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referralFee
    //        }
    //
    //        {
    //            uint256 user1BalBefore = user1.balance;
    //            uint256 receiverBalBefore = receiver.balance;
    //            uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
    //            uint256 user2BalBefore = user2.balance;
    //            vm.prank(user2);
    //            sharesFactory.buyShare{ value: 5501050111111109 }(0, 1, receiver);
    //            uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
    //            uint256 shareSupply = sharesNFT.totalSupply(0);
    //            assertEq(user2ShareBal, 1);
    //            assertEq(shareSupply, 2);
    //            uint256 user1BalAfter = user1.balance;
    //            uint256 receiverBalAfter = receiver.balance;
    //            uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
    //            uint256 user2BalAfter = user2.balance;
    //
    //            //console.log(factoryBalAfter - factoryBalBefore);
    //            //console.log(user2BalBefore - user2BalAfter);
    //            //console.log(user1BalAfter - user1BalBefore); // creatorFee
    //            //console.log(receiverBalAfter - receiverBalBefore); // referralFee
    //
    //            console.log("factory bal:", factoryBalAfter - factoryBalBefore);
    //            console.log("standardAmount:", 5000182222222220);
    //            assertEq(user2BalBefore - user2BalAfter, 5500200444444442); // totalPrice + gasFee
    //            assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
    //            assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referralFee
    //        }
    //    }
    //
    //    function testBlankYieldAggregatorOnlyFactory() public {
    //        vm.prank(owner);
    //        sharesFactory.migrate(address(blankYieldAggregator));
    //
    //        vm.prank(user1);
    //        vm.expectRevert(bytes("Only factory"));
    //        blankYieldAggregator.yieldDeposit();
    //
    //        vm.prank(user1);
    //        vm.expectRevert(bytes("Only factory"));
    //        blankYieldAggregator.yieldWithdraw(1);
    //    }
    //
    //    function testBlankYieldAggregatorYieldBalanceOf() public {
    //        uint256 amount = blankYieldAggregator.yieldBalanceOf(address(this));
    //        assertEq(amount, 0);
    //    }
    //
    //    function testBlankYieldAggregatorYieldMaxClaimable() public {
    //        uint256 amount = blankYieldAggregator.yieldMaxClaimable(0);
    //        assertEq(amount, 0);
    //    }
    //
    //    function testBlankYieldAggregatorCommonFunctions() public {
    //        // user1 send eth to blankYieldAggregator and trigger `receive`
    //        vm.deal(user1, 10 ether);
    //        vm.prank(user1);
    //        payable(address(blankYieldAggregator)).transfer(1 ether);
    //
    //        uint256 balanceOfBlankYieldAggregator = address(blankYieldAggregator).balance;
    //        assertEq(balanceOfBlankYieldAggregator, 1 ether);
    //    }
}
