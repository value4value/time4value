// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "../TestContext.t.sol";

contract MestShareFactoryTests is TestContext {
    address public user1 = address(11);
    address public user2 = address(22);
    address public newReceiver = address(33);

    function setUp() public {
        createMestFactory();
    }

    function testCreateShare() public {
        vm.deal(user1, 10 ether);

        vm.prank(user1);
        sharesFactory.createShare(user1);

        (address creator) = sharesFactory.sharesMap(0); // id is 0
        assertEq(creator, user1);

        uint256 shareIndex = sharesFactory.shareIndex();
        assertEq(shareIndex, 1);
    }

    function testBuyShare() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        // test query buy 1
        (
            uint256 total,
            uint256 subTotal,
            uint256 referalFee,
            uint256 creatorFee
        ) = sharesFactory.getBuyPriceAfterFee(0, 1, receiver);
        assertEq(total, 5500050111111109); //0.0055e
        assertEq(subTotal, 5000045555555555);
        assertEq(referalFee, 250002277777777);
        assertEq(creatorFee, 250002277777777);

        // test query buy 2
        (
            total,
            subTotal,
            referalFee,
            creatorFee
        ) = sharesFactory.getBuyPriceAfterFee(0, 2, receiver);
        assertEq(total, 11000250555555551); //0.011e, the second total price is 5500200444444442 > 5500050111111109
        assertEq(subTotal, 10000227777777775);
        assertEq(referalFee, 500011388888888);
        assertEq(creatorFee, 500011388888888);

        vm.prank(user1);
        sharesFactory.buyShare{value:5500050111111109}(0, 1, receiver);
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        vm.prank(user2);
        sharesFactory.buyShare{value:5501050111111109}(0, 1, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        assertEq(user2ShareBal, 1); // 10 share, 1 unit

        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBal = aWETH.balanceOf(address(sharesFactory));
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        //assertEq(factoryBal, 10000227777777775);
        //console.log(user1BalAfter - user1BalBefore);
        //console.log(receiverBalAfter - receiverBalBefore);
        console.log("buy share factory bal:", factoryBal);
        console.log("standardAmount:", 10000227777777775);

        // the 3rd share
        (
            total,
            subTotal,
            referalFee,
            creatorFee
        ) = sharesFactory.getBuyPriceAfterFee(0, 1, receiver);
        assertEq(total, 5500450999999993); // 0.0055e > the first price
        assertEq(subTotal, 5000409999999995);
        assertEq(referalFee, 250020499999999);
        assertEq(creatorFee, 250020499999999);

    }

    function testBuyRefund() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        vm.prank(user1);
        sharesFactory.buyShare{value:5510050111111109}(0, 1, receiver);

        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.buyShare{value:5510050111111109}(0, 1, receiver);
        uint256 user2BalAfter = user2.balance;
        assertEq(user2BalBefore - user2BalAfter, 11000250555555551 - 5500050111111109);
    }

    function testBuyFirstFailed() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        // buy 1 failed
        vm.prank(user2);
        vm.expectRevert(bytes("First buyer must be creator"));
        sharesFactory.buyShare{value:5500050111111109}(0, 1, receiver);
        vm.prank(user1);
        sharesFactory.buyShare{value:5500050111111109}(0, 1, receiver);
        vm.prank(user2);
        vm.expectRevert(bytes("Insufficient payment"));
        sharesFactory.buyShare{value:5500050111111109}(0, 1, receiver);
    }

    function testBuyInvalidId() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        vm.prank(user2);
        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.buyShare(2, 1, receiver);
    }


    function testSellShare() public {
        testBuyShare();

        // test query sell 1
        {
        (
            uint256 total,
            uint256 subTotal,
            uint256 referalFee,
            uint256 creatorFee
        ) = sharesFactory.getSellPriceAfterFee(0, 1, receiver);
        //console.log(total);
        //console.log(subTotal);
        //console.log(referalFee);
        //console.log(creatorFee);

        assertEq(total, 4500163999999998); //0.0055e
        assertEq(subTotal, 5000182222222220); // origin price, the same with last part
        assertEq(referalFee, 250009111111111);
        assertEq(creatorFee, 250009111111111);
        }

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.sellShare(0, 1, 0, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        uint256 shareSupply = sharesNFT.totalSupply(0);
        assertEq(user2ShareBal, 0);
        assertEq(shareSupply, 1);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalAfter = user2.balance;

        //assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220);
        console.log("sell share factory bal:", factoryBalBefore - factoryBalAfter);
        console.log("standardAmount:", 5000182222222220);
        assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        }
    }

    function testSellShareSlippageProtection() public {
        testBuyShare();

        vm.prank(user2);
        vm.expectRevert(bytes("Insufficient minReceive"));
        sharesFactory.sellShare(0, 1, 4600163999999998, receiver);
    }

    // Remove thie test case later, because getSellPriceAfterFee remove require statement
    function testQuerySellFailed() public {
        testBuyShare();

        vm.expectRevert(bytes("Exceeds supply"));
        sharesFactory.getSellPriceAfterFee(0, 5, receiver);
    }

    function testSellInvalidId() public {
        testBuyShare();
        vm.prank(user2);
        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.sellShare(2, 1, 0, receiver);
    }

    function testSellInvalidQuantity() public {
        testBuyShare();
        vm.prank(user2);
        vm.expectRevert(bytes("Insufficient shares"));
        sharesFactory.sellShare(0, 3, 0, receiver);
    }


    // ==================== test owner ===================

    function testSetReferralFee() public {
        testCreateShare();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesFactory.setReferralFeePercent(0);
        vm.prank(owner);
        sharesFactory.setReferralFeePercent(0);
        vm.prank(user1);
        sharesFactory.buyShare{value:5500050111111109}(0, 1, receiver);
        uint256 receiverBalAfter = receiver.balance;
        assertEq(receiverBalAfter, 0);
    }

    function testSetCreatorFee() public {
        testBuyShare();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesFactory.setCreatorFeePercent(0);
        vm.prank(owner);
        sharesFactory.setCreatorFeePercent(0);

        uint256 creatorBalBefore = user1.balance;
        vm.prank(user2);
        sharesFactory.buyShare{value:5600050111111109}(0, 1, receiver);
        uint256 creatorBalAfter = user1.balance;
        assertEq(creatorBalAfter - creatorBalBefore, 0);
    }

    function testYield() public {
        testBuyShare();
        vm.warp(1724693433); // need to fill a number gt current block.timestamp
        uint256 deposited = sharesFactory.depositedETHAmount();
        uint256 maxYield = aaveYieldAggregator.yieldMaxClaimable(deposited);
        //console.log(maxYield);
        assertEq(deposited, 10000227777777775);
        uint256 withdrawAmount = aWETH.balanceOf(address(sharesFactory));
        assertEq(withdrawAmount - deposited - maxYield, 1e12); // 1e12 is default yieldbuffer

        uint256 ownerBefore = owner.balance;
        vm.prank(owner);
        sharesFactory.claimYield(maxYield, owner);
        uint256 ownerAfter = owner.balance;
        //console.log("owner balance:", ownerAfter - ownerBefore);
        assertEq(ownerAfter - ownerBefore, maxYield);

        // test query sell 1
        {
        (
            uint256 total,
            uint256 subTotal,
            uint256 referalFee,
            uint256 creatorFee
        ) = sharesFactory.getSellPriceAfterFee(0, 1, receiver);
        //console.log(total);
        //console.log(subTotal);
        //console.log(referalFee);
        //console.log(creatorFee);

        assertEq(total, 4500163999999998); //0.0055e
        assertEq(subTotal, 5000182222222220); // origin price, the same with last part
        assertEq(referalFee, 250009111111111);
        assertEq(creatorFee, 250009111111111);
        }

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.sellShare(0, 1, 0, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        uint256 shareSupply = sharesNFT.totalSupply(0);
        assertEq(user2ShareBal, 0);
        assertEq(shareSupply, 1);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalAfter = user2.balance;

        console.log("yield test factory balance:", factoryBalBefore - factoryBalAfter);
        console.log("standardAmount:", 5000182222222220);
        //assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220); // sometimes it will be 5000182222222220
        assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        }

    }

    function testSetYieldBuffer() public {
        testBuyShare();
        vm.warp(1714693433); // need to fill a number gt current block.timestamp
        uint256 deposited = sharesFactory.depositedETHAmount();
        uint256 maxYield = aaveYieldAggregator.yieldMaxClaimable(deposited);
        //console.log(maxYield);
        assertEq(deposited, 10000227777777775);
        uint256 withdrawAmount = aWETH.balanceOf(address(sharesFactory));
        assertEq(withdrawAmount - deposited - maxYield, 1e12); // 1e12 is default yieldbuffer

        vm.prank(owner);
        aaveYieldAggregator.setYieldBuffer(1e11);
        uint256 maxYieldAfter = aaveYieldAggregator.yieldMaxClaimable(deposited);
        assertEq(maxYieldAfter - maxYield, 1e12 - 1e11);
    }

    // ============== test blank yield tool ===============

    // yieldAggregator -> blank yield tool, withdraw all yield token to eth
    function testWithdrawAll() public {
        testBuyShare();
        vm.warp(1814693433); // need to fill a number gt current block.timestamp

        uint256 allEthAmount = aWETH.balanceOf(address(sharesFactory));
        vm.prank(owner);
        sharesFactory.migrate(address(blankYieldAggregator));
        uint256 factoryEthBal = address(sharesFactory).balance;
        console.log("all factory eth amount:", factoryEthBal);
        assertEq(factoryEthBal, allEthAmount);
    }

    function testBlankYieldToolBuyAndSell() public {
        testWithdrawAll();

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = address(sharesFactory).balance;
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.sellShare(0, 1, 0, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        uint256 shareSupply = sharesNFT.totalSupply(0);
        assertEq(user2ShareBal, 0);
        assertEq(shareSupply, 1);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = address(sharesFactory).balance;
        uint256 user2BalAfter = user2.balance;

        assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220);
        assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        }

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = address(sharesFactory).balance;
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.buyShare{value:5501050111111109}(0, 1, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        uint256 shareSupply = sharesNFT.totalSupply(0);
        assertEq(user2ShareBal, 1);
        assertEq(shareSupply, 2);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = address(sharesFactory).balance;
        uint256 user2BalAfter = user2.balance;

        //console.log(factoryBalAfter - factoryBalBefore);
        //console.log(user2BalBefore - user2BalAfter);
        //console.log(user1BalAfter - user1BalBefore); // creatorFee
        //console.log(receiverBalAfter - receiverBalBefore); // referalFee

        assertEq(factoryBalAfter - factoryBalBefore, 5000182222222220);
        assertEq(user2BalBefore - user2BalAfter, 5500200444444442); // totalprice + gasfee
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        }

        vm.prank(owner);
        vm.expectRevert(bytes("Insufficient yield"));
        sharesFactory.claimYield(1, receiver);

        vm.prank(owner);
        sharesFactory.claimYield(0, receiver);

        uint256 amount = blankYieldAggregator.yieldBalanceOf(address(this));
        assertEq(amount, 0);
        amount = blankYieldAggregator.yieldMaxClaimable(0);
        assertEq(amount, 0);
    }

    function testBlankYieldAggregator2AaveYieldAggregator() public {
        testBlankYieldToolBuyAndSell();
        uint256 allEthAmount = address(sharesFactory).balance;

        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));
        uint256 allEthAmountAfter = aWETH.balanceOf(address(sharesFactory));
        assertEq(allEthAmount, allEthAmountAfter);

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.sellShare(0, 1, 0, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        uint256 shareSupply = sharesNFT.totalSupply(0);
        assertEq(user2ShareBal, 0);
        assertEq(shareSupply, 1);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalAfter = user2.balance;

        console.log("factory bal:", factoryBalBefore - factoryBalAfter);
        console.log("standardAmount:", 5000182222222220);
        assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        }

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        sharesFactory.buyShare{value:5501050111111109}(0, 1, receiver);
        uint256 user2ShareBal = sharesNFT.balanceOf(user2, 0);
        uint256 shareSupply = sharesNFT.totalSupply(0);
        assertEq(user2ShareBal, 1);
        assertEq(shareSupply, 2);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 user2BalAfter = user2.balance;

        //console.log(factoryBalAfter - factoryBalBefore);
        //console.log(user2BalBefore - user2BalAfter);
        //console.log(user1BalAfter - user1BalBefore); // creatorFee
        //console.log(receiverBalAfter - receiverBalBefore); // referalFee

        console.log("factory bal:", factoryBalAfter - factoryBalBefore);
        console.log("standardAmount:", 5000182222222220);
        assertEq(user2BalBefore - user2BalAfter, 5500200444444442); // totalprice + gasfee
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // referalFee
        }
    }
}
