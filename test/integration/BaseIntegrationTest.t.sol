pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { IAavePool } from "contracts/interface/IAave.sol";

contract BaseIntegrationTest is Test {
    address public SHARES_FOUNDER = makeAddr("founder");
    address public FACTORY_OWNER = makeAddr("factoryOwner");

    // spam roles
    address public SPAM_BOT = makeAddr("spamBot");
    address public HACKER = makeAddr("hacker");

    // normal traders
    address public DAILY_TRADER = makeAddr("dailyTrader");
    address public LONG_TERM_TRADER = makeAddr("longTermTrader");

    struct PresetCurveParams {
        uint96 basePrice;
        uint32 inflectionPoint;
        uint128 inflectionPrice;
        uint128 linearPriceSlope;
    }

    SharesERC1155 public sharesNFT;
    SharesFactoryV1 public sharesFactory;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;

    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant AAVE_WETH_GATEWAY = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;

    IERC20 public aWETH = IERC20(IAavePool(AAVE_POOL).getReserveData(WETH).aTokenAddress);

    string public constant BASE_URI = "https://foo.com/shares/uri/";

    PresetCurveParams public DEFAULT_CURVE_PARAMS = PresetCurveParams({
        basePrice: 0.005 ether,
        inflectionPoint: 1500,
        inflectionPrice: 0.01025 ether,
        linearPriceSlope: 0
    });

    PresetCurveParams public STANDARD_CURVE_PARAMS = PresetCurveParams({
        basePrice: 0.001 ether,
        inflectionPoint: 1500,
        inflectionPrice: 0.002 ether,
        linearPriceSlope: 0
    });

    PresetCurveParams public EXCLUSIVE_CURVE_PARAMS = PresetCurveParams({
        basePrice: 0.01 ether,
        inflectionPoint: 1500,
        inflectionPrice: 0.02 ether,
        linearPriceSlope: 0
    });

    uint8 public constant DEFAULT_CURVE_TYPE = 0;
    uint8 public constant STANDARD_CURVE_TYPE = 1;
    uint8 public constant EXCLUSIVE_CURVE_TYPE = 2;

    // common deploy contracts with args, call if needed
    function deployContracts() public {
        vm.startPrank(FACTORY_OWNER);
        sharesNFT = new SharesERC1155(BASE_URI);

        sharesFactory = new SharesFactoryV1(
            address(sharesNFT),
            DEFAULT_CURVE_PARAMS.basePrice,
            DEFAULT_CURVE_PARAMS.inflectionPoint,
            DEFAULT_CURVE_PARAMS.inflectionPrice,
            DEFAULT_CURVE_PARAMS.linearPriceSlope
        );

        aaveYieldAggregator = new AaveYieldAggregator(address(sharesFactory), WETH, AAVE_POOL, AAVE_WETH_GATEWAY);
        blankYieldAggregator = new BlankYieldAggregator(address(sharesFactory), WETH);


        sharesNFT.setFactory(address(sharesFactory));
        sharesFactory.resetYield(address(blankYieldAggregator));

        sharesNFT.transferOwnership(FACTORY_OWNER);
        aaveYieldAggregator.transferOwnership(FACTORY_OWNER);

        sharesFactory.transferOwnership(FACTORY_OWNER);
        sharesFactory.acceptOwnership();

        sharesFactory.queueMigrateYield(address(aaveYieldAggregator));
        vm.warp(block.timestamp + 4 days);
        sharesFactory.executeMigrateYield();

        vm.stopPrank();
    }

    // common set curve functions, call if need
    function createPresetCurveTypes() public {
        vm.startPrank(FACTORY_OWNER);
        sharesFactory.setCurveType(
            STANDARD_CURVE_TYPE,
            STANDARD_CURVE_PARAMS.basePrice,
            STANDARD_CURVE_PARAMS.inflectionPoint,
            STANDARD_CURVE_PARAMS.inflectionPrice,
            STANDARD_CURVE_PARAMS.linearPriceSlope
        );

        sharesFactory.setCurveType(
            EXCLUSIVE_CURVE_TYPE,
            EXCLUSIVE_CURVE_PARAMS.basePrice,
            EXCLUSIVE_CURVE_PARAMS.inflectionPoint,
            EXCLUSIVE_CURVE_PARAMS.inflectionPrice,
            EXCLUSIVE_CURVE_PARAMS.linearPriceSlope
        );
        vm.stopPrank();
    }

    // create buy histories as fixtures
    function createPresetBuyHistory(uint8 _tradeCount) public {
        uint8 tradeCount = 0;
        if (_tradeCount > 0) {
            tradeCount = _tradeCount;
        }

        vm.deal(DAILY_TRADER, 100 ether);
        vm.deal(LONG_TERM_TRADER, 100 ether);

        vm.prank(DAILY_TRADER);
        sharesFactory.mintShare(DEFAULT_CURVE_TYPE, '');
        uint256 shareId = sharesFactory.shareIndex() - 1;

        for (uint32 i = 0; i < tradeCount; i++) {
            _buyShare(DAILY_TRADER, shareId, 1, SHARES_FOUNDER);
        }

        uint256 currentBlockTime = block.timestamp;
        vm.warp(currentBlockTime + 10 minutes);

        for (uint32 i = 0; i < tradeCount; i++) {
            _buyShare(LONG_TERM_TRADER, shareId, 1, SHARES_FOUNDER);
        }

        console.log("[DEBUG]: After buy times %s, DAILY_TRADER balance", tradeCount, DAILY_TRADER.balance);
        console.log("[DEBUG]: After buy times %s, DAILY_TRADER balance", tradeCount, LONG_TERM_TRADER.balance);
    }

    // common initial contract with specific args
    // @dev call after deployContracts and if needed

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

    function test_success() public { }

    function _logToFile(string memory _path, string memory _messages) internal {
        vm.writeLine(_path, _messages);
    }
}
