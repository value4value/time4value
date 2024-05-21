// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { console } from "forge-std/console.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { IYieldAggregator } from "contracts/interface/IYieldAggregator.sol";
import { BaseTest } from "../BaseTest.t.sol";

contract SharesFactoryTests is BaseTest {
    function setUp() public {
        createFactory();
        _setUpShare();
    }

    function _setUpShare() internal {
        vm.deal(addrAlice, 10 ether);
        vm.deal(addrBob, 10 ether);

        // Alice mint & buy 1 share with 0 id
        vm.prank(addrAlice);
        sharesFactory.mintShare(defaultCurveType);
        _buyShare(addrAlice, 0, 1, referralReceiver);

        // Bob mintAndBuy 1 share with 1 id
        vm.prank(addrBob);
        _mintAndBuyShare(addrBob, defaultCurveType, 1, referralReceiver);

        // Alice buy 1 share with 1 id
        _buyShare(addrAlice, 1, 1, referralReceiver);

        // Bob buy 1 share with 0 id
        _buyShare(addrBob, 0, 1, referralReceiver);

        // Mock accumulated yield
        uint256 timestamp = block.timestamp;
        vm.warp(timestamp + 1 minutes);
    }

    function test_constructor() public view { 
        assertEq(aaveYieldAggregator.FACTORY(), address(sharesFactory));
        assertEq(aaveYieldAggregator.WETH(), WETH);
        assertEq(address(aaveYieldAggregator.aWETH()), address(aWETH));
        assertEq(address(aaveYieldAggregator.AAVE_POOL()), AAVE_POOL);
        assertEq(address(aaveYieldAggregator.AAVE_WETH_GATEWAY()), AAVE_WETH_GATEWAY);

        assertEq(blankYieldAggregator.FACTORY(), address(sharesFactory));
        assertEq(blankYieldAggregator.WETH(), WETH);
    }

    function test_mintShare() public {
        vm.prank(addrAlice);
        sharesFactory.mintShare(defaultCurveType);

        uint256 shareIndex = sharesFactory.shareIndex();
        (address creator, uint8 curveType) = sharesFactory.getShare(shareIndex - 1);

        assertEq(creator, addrAlice);
        assertEq(curveType, defaultCurveType);

        vm.expectRevert(bytes("Invalid curveType"));
        sharesFactory.mintShare(99);
    }

    function test_minAndBuyShare() public {
        vm.prank(addrBob);
        vm.deal(addrBob, 100 ether);
        _mintAndBuyShare(addrBob, defaultCurveType, 99, referralReceiver);

        uint256 shareId = sharesFactory.shareIndex() - 1;
        uint256 bobShareBal = sharesNFT.shareBalanceOf(addrBob, shareId);
        (address creator, uint8 curveType) = sharesFactory.getShare(shareId);

        assertEq(creator, addrBob);
        assertEq(curveType, defaultCurveType);
        assertEq(bobShareBal, 99);
    }

    function test_buyShares() public {
        uint256 aliceBalBefore = addrAlice.balance;
        uint256 bobBalBefore = addrBob.balance;
        uint256 referrerBalBefore = referralReceiver.balance;
        // uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountBefore = sharesFactory.depositedETHAmount();

        _buyShare(addrBob, 0, 1, referralReceiver);

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

    function test_sellShares() public {
        uint256 aliceBalBefore = addrAlice.balance;
        uint256 bobBalBefore = addrBob.balance;
        uint256 referrerBalBefore = referralReceiver.balance;
        // uint256 factoryBalBefore = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountBefore = sharesFactory.depositedETHAmount();

        _sellShare(addrAlice, 1, 1, referralReceiver);

        uint256 aliceBalAfter = addrAlice.balance;
        uint256 bobBalAfter = addrBob.balance;
        uint256 referrerBalAfter = referralReceiver.balance;
        // uint256 factoryBalAfter = aWETH.balanceOf(address(sharesFactory));
        uint256 depositedETHAmountAfter = sharesFactory.depositedETHAmount();

        assertEq(aliceBalAfter - aliceBalBefore, 4500163999999998); // Alice sell 1 share
        assertEq(bobBalAfter - bobBalBefore, 250009111111111); // Bob receive creator fee
        assertEq(referrerBalAfter - referrerBalBefore, 250009111111111); // Referral receive fee
        // assertEq(factoryBalBefore - factoryBalAfter, 5000182222222220); // Factory aWETH balance with rounding error
        assertEq(depositedETHAmountBefore - depositedETHAmountAfter, 5000182222222220); // Factory records ETH Amount

        uint256 aliceShareBal = sharesNFT.balanceOf(addrAlice, 1);
        assertEq(aliceShareBal, 0);
    }

    function test_claimYield() public {
        uint256 aliceBalBefore = addrAlice.balance;

        // check MaxClaimableYield < yieldBuffer
        (
            uint256 depositedETHAmountBefore,
            uint256 yieldBalanceBefore,
            uint256 yieldMaxClaimableBefore,
            uint256 yieldBufferBefore
        ) = _getYield();
        assertTrue(yieldBalanceBefore < (yieldBufferBefore + depositedETHAmountBefore));
        assertEq(yieldMaxClaimableBefore, 0);

        // Speed up time to claim yield
        vm.warp(YIELD_CLAIM_TIME);

        (
            uint256 depositedETHAmountAfter,
            uint256 yieldBalanceAfter,
            uint256 yieldMaxClaimableAfter,
            uint256 yieldBufferAfter
        ) = _getYield();

        // check MaxClaimableYield >= yieldBuffer
        assertTrue((yieldBalanceAfter - depositedETHAmountAfter) >= yieldBufferAfter);
        assertEq(yieldMaxClaimableAfter, yieldBalanceAfter - depositedETHAmountAfter - yieldBufferAfter);

        // check claimed yield
        vm.prank(owner);
        sharesFactory.claimYield(yieldMaxClaimableAfter, addrAlice);

        uint256 aliceBalAfter = addrAlice.balance;
        assertEq(aliceBalAfter - aliceBalBefore, yieldMaxClaimableAfter);
    }

    function test_migrate() public {
        uint256 factoryaWETHBalBefore = aWETH.balanceOf(address(sharesFactory));

        // Migrate to blankYieldAggregator
        vm.prank(owner);
        sharesFactory.migrate(address(blankYieldAggregator));
        assertEq(address(sharesFactory.yieldAggregator()), address(blankYieldAggregator));
        assertEq(aWETH.balanceOf(address(sharesFactory)), 0);
        assertEq(address(sharesFactory).balance, factoryaWETHBalBefore);

        // Migrate back to aaveYieldAggregator
        vm.prank(owner);
        sharesFactory.migrate(address(aaveYieldAggregator));
        assertEq(address(sharesFactory.yieldAggregator()), address(aaveYieldAggregator));
        assertEq(aWETH.balanceOf(address(sharesFactory)), factoryaWETHBalBefore);
        assertEq(address(sharesFactory).balance, 0);
    }

    function test_getShare() public {
        (address creator, uint8 curveType) = sharesFactory.getShare(0);
        assertEq(creator, addrAlice);
        assertEq(curveType, defaultCurveType);

        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.getShare(299);
    }

    function test_getCurve() public {
        // default curveType
        (
            uint256 basePrice, 
            uint256 inflectionPoint,
            uint256 inflectionPrice,
            uint256 linearPriceSlope, 
            bool exists
        ) = sharesFactory.getCurve(0);

        assertEq(exists, true);
        assertEq(basePrice, 5000000000000000);
        assertEq(inflectionPoint, 1500);
        assertEq(inflectionPrice, 102500000000000000);
        assertEq(linearPriceSlope, 0);

        // invalid curveType
        vm.expectRevert(bytes("Invalid curveType"));
        sharesFactory.getCurve(99);
    }

    function test_setReferralFeePercent() public {
        vm.prank(owner);
        sharesFactory.setReferralFeePercent(2 * 1e16);

        uint256 referralFeePercent = sharesFactory.referralFeePercent();
        assertEq(referralFeePercent, 2 * 1e16);
    }

    function test_setCreatorFeePercent() public {
        vm.prank(owner);
        sharesFactory.setCreatorFeePercent(3 * 1e16);

        uint256 creatorFeePercent = sharesFactory.creatorFeePercent();
        assertEq(creatorFeePercent, 3 * 1e16);
    }

    function test_setCurveType() public {
        vm.prank(owner);
        sharesFactory.setCurveType(1, 1000000000000000000, 1500, 102500000000000000, 0);

        (
            uint256 basePrice, 
            uint256 inflectionPoint,
            uint256 inflectionPrice,
            uint256 linearPriceSlope,
            bool exists
        ) = sharesFactory.getCurve(1);

        assertEq(exists, true);
        assertEq(basePrice, 1000000000000000000);
        assertEq(inflectionPoint, 1500);
        assertEq(inflectionPrice, 102500000000000000);
        assertEq(linearPriceSlope, 0);
    }

    function test_buySharesRefund() public {
        uint256 aliceBalBefore = addrAlice.balance;
        (uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(0, 1, referralReceiver);

        // Check revert if not enough value
        vm.prank(addrAlice);
        vm.expectRevert(bytes(""));
        sharesFactory.buyShare{ value: 1000 ether }(0, 1, referralReceiver);

        // Check refund if too much value
        vm.prank(addrAlice);
        sharesFactory.buyShare{ value: buyPriceAfterFee * 2 }(1, 1, referralReceiver);

        uint256 aliceBalAfter = addrAlice.balance;
        assertEq(aliceBalBefore - aliceBalAfter, buyPriceAfterFee);
    }

    /*
     ********************************************************************************
     * Failed Tests
     ********************************************************************************
     */

    function test_buySharesFailed() public {
        // invalid yieldAggregator, when sharesFactory not set yieldAggregator
        SharesFactoryV1 newSharesFactory = new SharesFactoryV1(
            address(sharesNFT),
            BASE_PRICE,
            INFLECTION_POINT,
            INFLECTION_PRICE,
            LINEAR_PRICE_SLOPE
        );
        vm.prank(addrAlice);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        newSharesFactory.buyShare{ value: 1 ether }(0, 1, referralReceiver);

        // invalid shareId, when id >= shareIndex
        uint256 shareIndex = sharesFactory.shareIndex();
        vm.startPrank(addrAlice);
        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.buyShare{ value: 1 ether }(shareIndex, 1, referralReceiver);
        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.buyShare{ value: 1 ether }(shareIndex * 999, 1, referralReceiver);
        vm.stopPrank();

        // invalid value, when value < buyPriceAfterFee
        (uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(0, 1, referralReceiver);
        vm.prank(addrAlice);
        vm.expectRevert(bytes("Insufficient payment"));
        sharesFactory.buyShare{ value: buyPriceAfterFee }(0, 2, referralReceiver);
    }

    function test_sellSharesFailed() public {
        (uint256 sellPriceAfterFee,,,) = sharesFactory.getSellPriceAfterFee(0, 1, referralReceiver);
        uint256 minETHAmount = (sellPriceAfterFee * 95) / 100;
        uint256 overETHAmount = (sellPriceAfterFee * 120) / 100;

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

        // referralReceiver is zero address
        (,, uint256 referralFee,) = sharesFactory.getSellPriceAfterFee(0, 1, address(0));
        assertEq(referralFee, 0);
    }

    function test_migrateFailed() public {
        vm.prank(addrAlice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesFactory.migrate(address(blankYieldAggregator));

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid yieldAggregator"));
        sharesFactory.migrate(address(0));

        // Revert if address isn't implemented IYieldAggregator
        vm.prank(owner);
        vm.expectRevert(bytes(""));
        sharesFactory.migrate(address(1));
    }

    function test_claimYieldFailed() public {
        uint256 maxAmount = aaveYieldAggregator.yieldMaxClaimable(1);

        vm.prank(addrAlice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesFactory.claimYield(maxAmount, yieldReceiver);

        vm.prank(owner);
        vm.expectRevert(bytes("Insufficient yield"));
        sharesFactory.claimYield(maxAmount + 1, yieldReceiver);
    }

    function test_getBuyPriceAfterFeeFailed() public {
        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.getBuyPriceAfterFee(999, 0, referralReceiver);

        // if quantity is zero, buyPriceAfterFee is zero
        (
            uint256 buyPriceAfterFee, 
            uint256 buyPrice, 
            uint256 creatorFee, 
            uint256 referralFee
        ) = sharesFactory.getBuyPriceAfterFee(1, 0, referralReceiver);
        assertEq(buyPriceAfterFee, 0);
        assertEq(buyPrice, 0);
        assertEq(creatorFee, 0);
        assertEq(referralFee, 0);
    }

    function test_getSellPriceAfterFeeFailed() public {
        vm.expectRevert(bytes("Invalid shareId"));
        sharesFactory.getSellPriceAfterFee(999, 999999, referralReceiver);

        vm.expectRevert(bytes("Exceeds supply"));
        sharesFactory.getSellPriceAfterFee(1, 999999, referralReceiver);

        // if quantity is zero, sellPriceAfterFee is zero
        (
            uint256 sellPriceAfterFee, 
            uint256 sellPrice, 
            uint256 creatorFee, 
            uint256 referralFee
        ) = sharesFactory.getSellPriceAfterFee(1, 0, referralReceiver);
        assertEq(sellPriceAfterFee, 0);
        assertEq(sellPrice, 0);
        assertEq(creatorFee, 0);
        assertEq(referralFee, 0);
    }

    function test_safeTransferETHWithZero() public {
        vm.prank(owner);
        sharesFactory.claimYield(0, yieldReceiver);
    }

    /*
     ********************************************************************************
     * Fuzz Tests
     ********************************************************************************
     */

    function testFuzz_setCurveTypeAndSubTotal(
        uint8 curveType,
        uint16 basePrice,
        uint16 inflectionPoint,
        uint32 inflectionPrice,
        uint32 linearPriceSlope,
        uint16 fromSupply,
        uint16 quantity
    ) public {
        vm.prank(owner);
        try sharesFactory.setCurveType(curveType, basePrice, inflectionPoint, inflectionPrice, linearPriceSlope) 
        {
            (, , , , bool exists) = sharesFactory.getCurve(curveType);
            assertEq(exists, true);
        } catch Error(string memory reason) {
            assertEq(reason, "Curve already initialized");
        }

        try sharesFactory.getSubTotal(fromSupply, quantity, curveType) returns (uint256 total) 
        {
            if (quantity == 0) {
                assertEq(total, 0);
            } else {
                assertGe(total, 0);
            }
        } catch Error(string memory reason) {
            console.log("testFuzz_setCurveTypeAndSubTotal:getSubTotal", reason);
        }
    }

    function testFuzz_getSellPriceAfterFee(uint32 quantity, address referral) public view {
        try sharesFactory.getSellPriceAfterFee(0, quantity, referral) returns (uint256 price, uint256, uint256, uint256) {
            assertGe(price, 0);
        } catch Error(string memory reason) {
            assertEq(reason, "Exceeds supply");
        }
    }

    function testFuzz_buyShare(uint8 quantity) public {
        vm.deal(addrBob, 100 ether);

        _mintAndBuyShare(addrBob, 0, quantity, addrAlice);
        test_safeTransferETHWithZero();
    }

    /*
     ********************************************************************************
     * Private Tests
     ********************************************************************************
     */

    function _mintAndBuyShare(address sender, uint8 curveType, uint32 quantity, address referral) internal {
        uint256 buyPrice = sharesFactory.getSubTotal(0, quantity, curveType);

        vm.prank(address(sender));
        sharesFactory.mintAndBuyShare{ value: buyPrice * 110 / 100 }(curveType, quantity, referral);
    }

    function _buyShare(address sender, uint256 shareId, uint32 quantity, address referral) internal {
        (uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(shareId, quantity, referral);

        vm.prank(address(sender));
        sharesFactory.buyShare{ value: buyPriceAfterFee }(shareId, quantity, referral);
    }

    function _sellShare(address sender, uint256 shareId, uint32 quantity, address referral) internal {
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
        return (depositedETHAmount, yieldBalance, yieldMaxClaimable, yieldBuffer);
    }
}
