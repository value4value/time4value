/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "./TestContext.t.sol";

contract TestMestShareFactory is TestContext {
    address public user1 = address(11);
    address public user2 = address(22);
    address public newReceiver = address(33);


    function setUp() public {
        createMestFactory();
    }
    

    function testCreateShare() public {
        vm.deal(user1, 10 ether);

        vm.prank(user1);
        mestFactory.createShare(user1); 

        (address creator)= mestFactory.sharesMap(0); // id is 0
        assertEq(creator, user1);
        string memory shareUri = erc1155TokenTemp.uri(0);
        assertEq(shareUri, "http://mest.io/share/0");
    }

    
    function testBuyShare() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        // test query buy 1
        (
            uint256 total, 
            uint256 subTotal, 
            uint256 protocolFee, 
            uint256 creatorFee
        ) = mestFactory.getBuyPriceAfterFee(0, 1);
        assertEq(total, 5500050111111109); //0.0055e
        assertEq(subTotal, 5000045555555555);
        assertEq(protocolFee, 250002277777777);
        assertEq(creatorFee, 250002277777777);

        // test query buy 2
        (
            total, 
            subTotal, 
            protocolFee, 
            creatorFee
        ) = mestFactory.getBuyPriceAfterFee(0, 2);
        assertEq(total, 11000250555555551); //0.011e, the second total price is 5500200444444442 > 5500050111111109
        assertEq(subTotal, 10000227777777775);
        assertEq(protocolFee, 500011388888888);
        assertEq(creatorFee, 500011388888888);

        vm.prank(user1);
        mestFactory.buyShare{value:5500050111111109}(0, 1);
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        vm.prank(user2);
        mestFactory.buyShare{value:5501050111111109}(0, 1);
        uint256 user2ShareBal = erc1155TokenTemp.balanceOf(user2, 0);
        assertEq(user2ShareBal, 1); // 10 share, 1 unit

        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBal = address(mestFactory).balance;
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // protocolFee
        assertEq(factoryBal, 10000227777777775);
        //console.log(user1BalAfter - user1BalBefore);
        //console.log(receiverBalAfter - receiverBalBefore);
        //console.log(factoryBal);

        // the 3rd share
        (
            total, 
            subTotal, 
            protocolFee, 
            creatorFee
        ) = mestFactory.getBuyPriceAfterFee(0, 1);
        assertEq(total, 5500450999999993); // 0.0055e > the first price
        assertEq(subTotal, 5000409999999995);
        assertEq(protocolFee, 250020499999999);
        assertEq(creatorFee, 250020499999999);

    }

    function testBuyRefund() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        vm.prank(user1);
        mestFactory.buyShare{value:5510050111111109}(0, 1);

        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        mestFactory.buyShare{value:5510050111111109}(0, 1);
        uint256 user2BalAfter = user2.balance;
        assertEq(user2BalBefore - user2BalAfter, 11000250555555551 - 5500050111111109);
    }

    function testBuyFirstFailed() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        // buy 1 failed
        vm.prank(user2);
        vm.expectRevert(bytes("First buyer must be creator"));
        mestFactory.buyShare{value:5500050111111109}(0, 1);
        vm.prank(user1);
        mestFactory.buyShare{value:5500050111111109}(0, 1);
        vm.prank(user2);
        vm.expectRevert(bytes("Insufficient payment"));
        mestFactory.buyShare{value:5500050111111109}(0, 1);
    }

    function testBuyInvalidId() public {
        testCreateShare();
        vm.deal(user2, 10 ether);

        vm.prank(user2);
        vm.expectRevert(bytes("Invalid shareId"));
        mestFactory.buyShare(2, 1);
    }

    
    function testSellShare() public {
        testBuyShare();

        // test query sell 1
        {
        (
            uint256 total, 
            uint256 subTotal, 
            uint256 protocolFee, 
            uint256 creatorFee
        ) = mestFactory.getSellPriceAfterFee(0, 1);
        //console.log(total); 
        //console.log(subTotal);
        //console.log(protocolFee);
        //console.log(creatorFee);

        assertEq(total, 4500163999999998); //0.0055e
        assertEq(subTotal, 5000182222222220); // origin price, the same with last part
        assertEq(protocolFee, 250009111111111);
        assertEq(creatorFee, 250009111111111);
        }

        {
        uint256 user1BalBefore = user1.balance;
        uint256 receiverBalBefore = receiver.balance;
        uint256 factoryBalBefore = address(mestFactory).balance;
        uint256 user2BalBefore = user2.balance;
        vm.prank(user2);
        mestFactory.sellShare(0, 1, 0);
        uint256 user2ShareBal = erc1155TokenTemp.balanceOf(user2, 0);
        uint256 shareSupply = erc1155TokenTemp.totalSupply(0);
        assertEq(user2ShareBal, 0); 
        assertEq(shareSupply, 1);
        uint256 user1BalAfter = user1.balance;
        uint256 receiverBalAfter = receiver.balance;
        uint256 factoryBalAfter = address(mestFactory).balance;
        uint256 user2BalAfter = user2.balance;

        assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220);
        assertEq(user2BalAfter - user2BalBefore, 4500163999999998);
        assertEq(user1BalAfter - user1BalBefore, 250009111111111); // creatorFee
        assertEq(receiverBalAfter - receiverBalBefore, 250009111111111); // protocolFee
        }
    }

    function testSellShareSlippageProtection() public {
        testBuyShare();

        vm.prank(user2);
        vm.expectRevert(bytes("Insufficient minReceive"));
        mestFactory.sellShare(0, 1, 4600163999999998);
    }

    function testQuerySellFailed() public {
        testBuyShare();

        vm.expectRevert(bytes("Exceeds supply"));
        mestFactory.getSellPriceAfterFee(0, 5);
    }

    function testSellInvalidId() public {
        testBuyShare();
        vm.prank(user2);
        vm.expectRevert(bytes("Invalid shareId"));
        mestFactory.sellShare(2, 1, 0);
    }

    function testSellInvalidQuantity() public {
        testBuyShare();
        vm.prank(user2);
        vm.expectRevert(bytes("Insufficient shares"));
        mestFactory.sellShare(0, 3, 0);
    }
    

    // ==================== test owner ===================
    function testSetProtocolFeeReceiver() public {
        testCreateShare();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        mestFactory.setProtocolFeeReceiver(newReceiver);
        vm.prank(owner);
        mestFactory.setProtocolFeeReceiver(newReceiver);
        vm.prank(user1);
        mestFactory.buyShare{value:5500050111111109}(0, 1);
        uint256 receiverBalAfter = newReceiver.balance;
        assertEq(receiverBalAfter, 250002277777777);

    }

    function testSetProtocolFee() public {
        testCreateShare();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        mestFactory.setProtocolFeePercent(0);
        vm.prank(owner);
        mestFactory.setProtocolFeePercent(0);
        vm.prank(user1);
        mestFactory.buyShare{value:5500050111111109}(0, 1);
        uint256 receiverBalAfter = receiver.balance;
        assertEq(receiverBalAfter, 0);
    }

    function testSetCreatorFee() public {
        testBuyShare();

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        mestFactory.setCreatorFeePercent(0);
        vm.prank(owner);
        mestFactory.setCreatorFeePercent(0);

        uint256 creatorBalBefore = user1.balance;
        vm.prank(user2);
        mestFactory.buyShare{value:5600050111111109}(0, 1);
        uint256 creatorBalAfter = user1.balance;
        assertEq(creatorBalAfter - creatorBalBefore, 0);
    }
}