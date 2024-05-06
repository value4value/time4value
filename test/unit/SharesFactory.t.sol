// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "../TestContext.t.sol";

contract SharesFactoryTests is TestContext {
	address public addrAlice = address(2);
    address public addrBob = address(3);
    address public referralReceiver = address(4);

    function setUp() public {
    	createMestFactory();
		_setUpShare();
   	}

 	function _setUpShare() internal {
        vm.deal(addrAlice, 10 ether);
        vm.deal(addrBob, 10 ether);

		// Alice create & buy 1 share with 0 id
        vm.prank(addrAlice);
        sharesFactory.createShare(addrAlice);
		_buyShare(addrAlice, 0, 1, referralReceiver);

		// Bob create & buy 1 share with 1 id
        vm.prank(addrBob);
        sharesFactory.createShare(addrBob);
		_buyShare(addrBob, 1, 1, referralReceiver);

		// Alice buy 1 share with 1 id
		_buyShare(addrAlice, 1, 1, referralReceiver);

		// Bob buy 1 share with 0 id
		_buyShare(addrBob, 0, 1, referralReceiver);
    }

  	function testCreateShares() public {
        vm.prank(addrAlice);
        sharesFactory.createShare(addrAlice);

        uint256 shareIndex = sharesFactory.shareIndex();
        (address creator) = sharesFactory.sharesMap(shareIndex - 1); 

        assertEq(creator, addrAlice);
  	}

	function testBuyShares() public {
        uint256 aliceBalBefore = addrAlice.balance;
		uint256 bobBalBefore = addrBob.balance;
        uint256 referralerBalBefore = referralReceiver.balance;
		// uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
		uint256 depositedETHAmountBefore = sharesFactory.depositedETHAmount();
		
		_buyShare(addrBob, 0, 1, referralReceiver);

		uint256 aliceBalAfter = addrAlice.balance;
		uint256 bobBalAfter = addrBob.balance;
		uint256 referralerBalAfter = referralReceiver.balance;
		// uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
		uint256 depositedETHAmountAfter = sharesFactory.depositedETHAmount();

		assertEq(bobBalBefore - bobBalAfter, 5500450999999993); // Bob buy 1 share
        assertEq(aliceBalAfter - aliceBalBefore, 250020499999999); // Alice receive creator fee
        assertEq(referralerBalAfter - referralerBalBefore, 250020499999999); // referral receive fee
		// assertEq(factoryBalAfter - factoryBalBefore, 5000409999999995); // Factory aWETH balance with rounding error
		assertEq(depositedETHAmountAfter - depositedETHAmountBefore, 5000409999999995); // Factory records ETH Amount

        uint256 bobShareBal = sharesNFT.balanceOf(addrBob, 0);
        assertEq(bobShareBal, 2);
	}

	function testSellShares() public {
		uint256 aliceBalBefore = addrAlice.balance;
		uint256 bobBalBefore = addrBob.balance;
		uint256 referralerBalBefore = referralReceiver.balance;
		// uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
		uint256 depositedETHAmountBefore = sharesFactory.depositedETHAmount();
		
		_sellShare(addrAlice, 1, 1, referralReceiver);

		uint256 aliceBalAfter = addrAlice.balance;
		uint256 bobBalAfter = addrBob.balance;
		uint256 referralerBalAfter = referralReceiver.balance;
		// uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
		uint256 depositedETHAmountAfter = sharesFactory.depositedETHAmount();

		assertEq(aliceBalAfter - aliceBalBefore, 4500163999999998); // Alice sell 1 share
		assertEq(bobBalAfter - bobBalBefore, 250009111111111); // Bob receive creator fee
		assertEq(referralerBalAfter - referralerBalBefore, 250009111111111); // Referral receive fee
		// assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220); // Factory aWETH balance with rounding error
		assertEq(depositedETHAmountBefore - depositedETHAmountAfter, 5000182222222220); // Factory records ETH Amount

		uint256 aliceShareBal = sharesNFT.balanceOf(addrAlice, 1);
		assertEq(aliceShareBal, 0);
	}

	function testClaimYield() public {
		uint256 aliceBalBefore = addrAlice.balance;

		// check MaxclaimableYield < yieldBuffer
		( 
			uint256 depositedETHAmountBefore, 
			uint256 yieldBalanceBefore, 
			uint256 yieldMaxClaimableBefore, 
			uint256 yieldBufferBefore
		) = _getYield();
		assertTrue((yieldBalanceBefore - depositedETHAmountBefore) < yieldBufferBefore);
		assertEq(yieldMaxClaimableBefore, 0);

		// Speed up time to claim yield
		// 2029-11-01 00:00:30
		vm.warp(1857507630); 
		( 
			uint256 depositedETHAmountAfter, 
			uint256 yieldBalanceAfter, 
			uint256 yieldMaxClaimableAfter, 
			uint256 yieldBufferAfter
		) = _getYield();

		// check MaxclaimableYield >= yieldBuffer
		assertTrue((yieldBalanceAfter - depositedETHAmountAfter) >= yieldBufferAfter);
		assertEq(yieldMaxClaimableAfter, yieldBalanceAfter - depositedETHAmountAfter - yieldBufferAfter);

		// check claimed yield
		vm.prank(owner);
		sharesFactory.claimYield(yieldMaxClaimableAfter, addrAlice);

		uint256 aliceBalAfter = addrAlice.balance;
		assertEq(aliceBalAfter - aliceBalBefore, yieldMaxClaimableAfter);
	}

	function testMigrate() public {
		uint256 factoryaWETHBalBefore = aWETH.balanceOf(address(sharesFactory));
		uint256 factoryETHBalBefore = address(sharesFactory).balance;

		vm.prank(owner);
		sharesFactory.migrate(address(blankYieldAggregator));
		
		address newYieldAggregator = address(sharesFactory.yieldAggregator());
		uint256 factoryaWETHBalAfter = aWETH.balanceOf(address(sharesFactory));
		uint256 factoryETHBalAfter = address(sharesFactory).balance;

		assertEq(newYieldAggregator, address(blankYieldAggregator));
		assertEq(factoryaWETHBalBefore - factoryaWETHBalAfter, factoryaWETHBalBefore);
		assertEq(factoryETHBalAfter - factoryETHBalBefore, factoryaWETHBalBefore);

		// switch back
	}

	function testSetReferralFeePercent() public {
		vm.prank(owner);
		sharesFactory.setReferralFeePercent(2 * 1e16);

		uint256 referralFeePercent = sharesFactory.referralFeePercent();
		assertEq(referralFeePercent, 2 * 1e16);
	}

	function testSetCreatorFeePercent() public {
		vm.prank(owner);
		sharesFactory.setCreatorFeePercent(3 * 1e16);

		uint256 creatorFeePercent = sharesFactory.creatorFeePercent();
		assertEq(creatorFeePercent, 3 * 1e16);
	}

	// Negative test cases
	function testBuySharesRefund() public {
		uint256 aliceBalBefore = addrAlice.balance;
		(uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(0, 1, referralReceiver);

		// Check revert if not enough value
		vm.prank(addrAlice);
		vm.expectRevert(bytes(""));
		sharesFactory.buyShare{value: 1000 ether}(0, 1, referralReceiver);

		// Check refund if too much value
		vm.prank(addrAlice);
		sharesFactory.buyShare{value: buyPriceAfterFee * 2}(1, 1, referralReceiver);

		uint256 aliceBalAfter = addrAlice.balance;
		assertEq(aliceBalBefore - aliceBalAfter, buyPriceAfterFee);
	}

	function testBuySharesFailed() public {
		// invalid shareId, when id >= shareIndex
		uint256 shareIndex = sharesFactory.shareIndex();

		vm.prank(addrAlice);
		vm.expectRevert(bytes("Invalid shareId"));
		sharesFactory.buyShare{value: 1 ether}(shareIndex, 1, referralReceiver);

		vm.prank(addrAlice);
		vm.expectRevert(bytes("Invalid shareId"));
		sharesFactory.buyShare{value: 1 ether}(shareIndex * 999, 1, referralReceiver);

		// invalid buyer, when alice create shares, only alice can buy it first
		vm.prank(addrAlice);
		sharesFactory.createShare(addrAlice);

		vm.prank(addrBob);
		vm.expectRevert(bytes("First buyer must be creator"));
		sharesFactory.buyShare{value: 1 ether}(shareIndex, 1, referralReceiver);

		// invalid value, when value < buyPriceAfterFee
		(uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(0, 1, referralReceiver);
		vm.prank(addrAlice);
		vm.expectRevert(bytes("Insufficient payment"));
		sharesFactory.buyShare{value: buyPriceAfterFee / 2}(0, 1, referralReceiver);
	}

	function testSellSharesFailed() public {
		(uint256 sellPriceAfterFee,,,) = sharesFactory.getSellPriceAfterFee(0, 1, referralReceiver);
		uint256 minETHAmount = sellPriceAfterFee * 95 / 100;
		uint256 overETHAmount = sellPriceAfterFee * 120 / 100;

		// invalid shareId
		vm.prank(addrAlice);
		vm.expectRevert(bytes("Invalid shareId"));
		sharesFactory.sellShare(999, 1, minETHAmount, referralReceiver);

		// invalid quantity
		vm.prank(addrAlice);
		vm.expectRevert(bytes("Insufficient shares"));
		sharesFactory.sellShare(0, 999, minETHAmount, referralReceiver);

		// invalid minETHAmount
		vm.prank(addrAlice);
		vm.expectRevert(bytes("Insufficient minReceive"));
		sharesFactory.sellShare(0, 1, overETHAmount, referralReceiver);
	}

	function _buyShare(address sender, uint256 shareId, uint256 quantity, address referral) internal {
		(uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(shareId, quantity, referral);
		vm.prank(address(sender));
		sharesFactory.buyShare{value: buyPriceAfterFee}(shareId, quantity, referral);
	}

	function _sellShare(address sender, uint256 shareId, uint256 quantity, address referral) internal {
		(uint256 sellPriceAfterFee,,,) = sharesFactory.getSellPriceAfterFee(shareId, quantity, referral);
		vm.prank(address(sender));
		sharesFactory.sellShare(shareId, quantity, sellPriceAfterFee, referral);
	}

	function _getYield() internal view returns (uint256, uint256, uint256, uint256) {
		IYieldAggregator yieldAggregator = sharesFactory.yieldAggregator();
		uint256 depositedETHAmount = sharesFactory.depositedETHAmount();
		uint256 yieldBalance = yieldAggregator.yieldBalanceOf(address(sharesFactory));
		uint256 yieldMaxClaimable = yieldAggregator.yieldMaxClaimable(depositedETHAmount);
		uint256 yieldBuffer = 1e12;
		// uint256 yieldBuffer = yieldAggregator.yieldBuffer();
		console.log("depositedETHAmount: ", depositedETHAmount);
		console.log("yieldBalance: ", yieldBalance);
		console.log("yieldMaxClaimable: ", yieldMaxClaimable);
		return (depositedETHAmount, yieldBalance, yieldMaxClaimable, yieldBuffer);
	}

  	// Add more test functions as needed

}