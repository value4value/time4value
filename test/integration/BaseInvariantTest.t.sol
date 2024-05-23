pragma solidity ^0.8.25;

import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { IAavePool } from "contracts/interface/IAave.sol";
import { Vm } from "forge-std/Vm.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { BoundedIntegrationContextHandler } from "./handlers/BoundedIntegrationContextHandler.t.sol";

contract BaseInvariantTest is StdInvariant {
    // @dev exclude contracts for invariant testing , need to be initialized and use manual addr
    address public SHARES_FOUNDER = address(1);
    address public FACTORY_OWNER = address(2);

    SharesERC1155 public sharesNFT;
    SharesFactoryV1 public sharesFactory;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;

    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant AAVE_WETH_GATEWAY = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;

    IERC20 public aWETH = IERC20(IAavePool(AAVE_POOL).getReserveData(WETH).aTokenAddress);

    string public constant BASE_URI = "https://foo.com/shares/uri/";

    struct PresetCurveParams {
        uint96 basePrice;
        uint32 inflectionPoint;
        uint128 inflectionPrice;
        uint128 linearPriceSlope;
    }

    PresetCurveParams public DEFAULT_CURVE_PARAMS = PresetCurveParams({
        basePrice: 0.005 ether,
        inflectionPoint: 1500,
        inflectionPrice: 0.01025 ether,
        linearPriceSlope: 0
    });

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    // @dev target handlers for invariant testing
    BoundedIntegrationContextHandler public integrationContext;

    // helper functions
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
        sharesFactory.queueMigrateYield(address(aaveYieldAggregator));
        vm.warp(block.timestamp + sharesFactory.TIMELOCK_DURATION());
        sharesFactory.executeMigrateYield();

        sharesNFT.transferOwnership(FACTORY_OWNER);
        sharesFactory.transferOwnership(FACTORY_OWNER);
        aaveYieldAggregator.transferOwnership(FACTORY_OWNER);
        vm.stopPrank();
    }

    function excludeDeployedContracts() public {
        excludeContract(address(sharesNFT));
        excludeContract(address(sharesFactory));
        excludeContract(address(aaveYieldAggregator));
        excludeContract(address(blankYieldAggregator));

        excludeContract(address(aWETH));
        excludeContract(address(SHARES_FOUNDER));
        excludeContract(address(FACTORY_OWNER));
    }

    function setUp() public {
        deployContracts();
        excludeDeployedContracts();

        integrationContext = new BoundedIntegrationContextHandler(FACTORY_OWNER, sharesFactory, sharesNFT);
        targetContract(address(integrationContext));
    }

    function invariant_depositedETHAmount() public view {
        vm.assertEq(sharesFactory.depositedETHAmount(), aWETH.balanceOf(address(aaveYieldAggregator)));
    }

    function invariant_logSummary() public view {
        console.log("\n");
        console.log("Log Summary: ");

        console.log(
            "Num calls: boundedIntContext.setCurveType: ", integrationContext.numCalls("boundedIntContext.setCurveType")
        );
        console.log("Num calls: boundedIntContext.buy: ", integrationContext.numCalls("boundedIntContext.buy"));
        console.log("Num calls: boundedIntContext.test: ", integrationContext.numCalls("boundedIntContext.test"));
    }

    function test_success() public pure {
        vm.assertTrue(true);
    }
}
