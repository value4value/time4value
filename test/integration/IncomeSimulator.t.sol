pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { IAavePool } from "contracts/interface/IAave.sol";
import { BaseIntegrationTest } from "./BaseIntegrationTest.t.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { LogUtil } from "../lib/LogUtil.t.sol";

contract IncomeSimulator is BaseIntegrationTest, LogUtil {
    using SafeMath for uint256;
    using Strings for uint256;
    using Strings for uint128;
    using Strings for uint96;
    using Strings for uint32;
    using Strings for uint8;

    uint128 public constant TRADER_BALANCE = 100000 ether;

    uint256 public constant BUY_DURATION = 0.2 days;
    uint256 public constant YIELD_DURATION = 365 days;
    uint256 public constant TARGET_INCOME = 1.5 ether;
    uint32 public constant TARGET_SUPPLY = 1000;

    uint256 public constant YIELD_BUFFER = 0.05 ether;

    uint8 public curveIndex = 0;

    function setUp() public {
        deployContracts();
    }

    function testFuzz_SimulateLinearCurveParams(uint256 _seed) public {
        uint96 minBasePrice = 0.02 ether;
        uint96 maxBasePrice = 0.1 ether;

        uint128 minLinearPriceSlope = 0;
        uint128 maxLinearPriceSlope = 100000;

        // random params
        uint96 basePrice = uint96(_random96(_seed, minBasePrice, maxBasePrice));
        uint128 linearPriceSlope = uint128(_random128(_seed, minLinearPriceSlope, maxLinearPriceSlope));

        _simulateLinearCurveParams(basePrice, linearPriceSlope);
    }

    function testFuzz_SimulateSigmoidCurveParams(uint256 _seed) public {
        uint96 minBasePrice = 0.02 ether;
        uint96 maxBasePrice = 0.1 ether;

        uint128 minLinearPriceSlope = 0;
        uint128 maxLinearPriceSlope = 100000;

        uint32 minInflectionPoint = 100;
        uint32 maxInflectionPoint = 1000;

        uint128 minInflectionPrice = 0.02 ether;
        uint128 maxInflectionPrice = 0.05 ether;

        // random params
        uint96 basePrice = uint96(_random96(_seed, minBasePrice, maxBasePrice));
        uint128 linearPriceSlope = uint128(_random128(_seed, minLinearPriceSlope, maxLinearPriceSlope));
        uint32 inflectionPoint = uint32(_random32(_seed, minInflectionPoint, maxInflectionPoint));
        uint128 inflectionPrice = uint128(_random128(_seed, minInflectionPrice, maxInflectionPrice));

        _simulateSigmoidCurveParams(basePrice, linearPriceSlope, inflectionPoint, inflectionPrice);
    }

    function testFuzz_SimulateExclusiveSigmoidCurveParams(uint256 _seed) public {
        // @dev exclusive sigmoid curve params has extreme high inflectionPoint
        uint96 minBasePrice = 0.015 ether;
        uint96 maxBasePrice = 0.1 ether;

        uint128 minLinearPriceSlope = 0;
        uint128 maxLinearPriceSlope = 100000;

        uint32 minInflectionPoint = 100;
        uint32 maxInflectionPoint = 1000;

        uint128 minInflectionPrice = 0.02 ether;
        uint128 maxInflectionPrice = 0.1 ether;

        // random params
        uint96 basePrice = uint96(_random96(_seed, minBasePrice, maxBasePrice));
        uint128 linearPriceSlope = uint128(_random128(_seed, minLinearPriceSlope, maxLinearPriceSlope));
        uint32 inflectionPoint = uint32(_random32(_seed, minInflectionPoint, maxInflectionPoint));
        uint128 inflectionPrice = uint128(_random128(_seed, minInflectionPrice, maxInflectionPrice));

        _simulateExclusiveSigmoidCurveParams(basePrice, linearPriceSlope, inflectionPoint, inflectionPrice);
    }

    function _simulateLinearCurveParams(uint96 _basePrice, uint128 _linearPriceSlope) public {
        deployContracts(); // redeploy contracts

        (uint256 income, uint8 reachTargetInDays) = _simulateClaimableAmountAndFee(
            _basePrice, _linearPriceSlope, 0, 0, TARGET_SUPPLY, BUY_DURATION, YIELD_DURATION
        );
        console.log("Reach target in days: ", reachTargetInDays, "Income: ", income);

        if (income < TARGET_INCOME) return;

        _logSummary(
            "linear_curve_params",
            _contactString(
                "LinearCurveParams: ",
                _basePrice.toString(),
                ",",
                _linearPriceSlope.toString(),
                ", ReachTargetInDays: ",
                reachTargetInDays.toString(),
                ", Income: ",
                income.toString()
            )
        );
    }

    function _simulateSigmoidCurveParams(
        uint96 _basePrice,
        uint128 _linearPriceSlope,
        uint32 _inflectionPoint,
        uint128 _inflectionPrice
    ) public {
        deployContracts(); // redeploy contracts

        (uint256 income, uint8 reachTargetInDays) = _simulateClaimableAmountAndFee(
            _basePrice,
            _linearPriceSlope,
            _inflectionPoint,
            _inflectionPrice,
            TARGET_SUPPLY,
            BUY_DURATION,
            YIELD_DURATION
        );
        console.log("Reach target in days: ", reachTargetInDays, "Income: ", income);

        if (income < TARGET_INCOME) return;

        string memory params = _contactString(
            "SigmoidCurveParams: ",
            _basePrice.toString(),
            ",",
            _linearPriceSlope.toString(),
            ",",
            _inflectionPoint.toString(),
            ",",
            _inflectionPrice.toString()
        );
        string memory results =
            _contactString(", ReachTargetInDays: ", reachTargetInDays.toString(), ", Income: ", income.toString());
        _logSummary("sigmoid_curve_params", _contactString(params, results));
    }

    function _simulateExclusiveSigmoidCurveParams(
        uint96 _basePrice,
        uint128 _linearPriceSlope,
        uint32 _inflectionPoint,
        uint128 _inflectionPrice
    ) public {
        deployContracts(); // redeploy contracts

        (uint256 income, uint8 reachTargetInDays) = _simulateClaimableAmountAndFee(
            _basePrice,
            _linearPriceSlope,
            _inflectionPoint,
            _inflectionPrice,
            TARGET_SUPPLY,
            BUY_DURATION,
            YIELD_DURATION
        );
        console.log("Reach target in days: ", reachTargetInDays, "Income: ", income);

        if (income < TARGET_INCOME) return;
        string memory params = _contactString(
            "ExclusiveSigmoidCurveParams: ",
            _basePrice.toString(),
            ",",
            _linearPriceSlope.toString(),
            ",",
            _inflectionPoint.toString(),
            ",",
            _inflectionPrice.toString()
        );
        string memory results =
            _contactString(", ReachTargetInDays: ", reachTargetInDays.toString(), ", Income: ", income.toString());
        _logSummary("exclusive_sigmoid_curve_params", _contactString(params, results));
    }

    function _simulateClaimableAmountAndFee(
        // curve params
        uint96 _basePrice,
        uint128 _linearPriceSlope,
        uint32 _inflectionPoint,
        uint128 _inflectionPrice,
        // target supply
        uint32 _targetSupply,
        // buy duration
        uint256 _buyDuration,
        // yield duration
        uint256 _yieldDuration
    ) public returns (uint256 income, uint8 reachTargetInDays) {
        reachTargetInDays = 0;

        uint8 curveType = curveIndex + 1;
        curveIndex++;
        // create and set curve type
        vm.prank(FACTORY_OWNER);
        sharesFactory.setCurveType(curveType, _basePrice, _inflectionPoint, _inflectionPrice, _linearPriceSlope);

        // mint shares
        vm.prank(FACTORY_OWNER);
        sharesFactory.mintShare(curveType);

        // record start balance
        uint256 founderBalanceBefore = aWETH.balanceOf(address(SHARES_FOUNDER));
        console.log("Founder Start Balance: ", founderBalanceBefore);

        // buy shares
        vm.deal(DAILY_TRADER, TRADER_BALANCE);
        uint256 startBlockTime = block.timestamp;
        for (uint32 i = 0; i < _targetSupply; i++) {
            vm.warp(startBlockTime + i * _buyDuration);
            _buyShare(DAILY_TRADER, sharesFactory.shareIndex() - 1, 1, SHARES_FOUNDER);

            // check max claimable amount
            uint256 currentClaimableAmount = _checkClaimableAmountAndFee();
            //            _logSummary(_contactString("Total supply: ", i.toString(), ", CurrentClaimableAmount:", currentClaimableAmount.toString()));
            // once claimableAmount >  targetIncome
            if (currentClaimableAmount > TARGET_INCOME && reachTargetInDays == 0) {
                reachTargetInDays = uint8((i * _buyDuration) / (1 days));
                console.log("This params earn income after days: ", reachTargetInDays);
            }
        }

        // time flies
        vm.assertTrue(_yieldDuration > _buyDuration * _targetSupply);

        // after soling TARGET_SUPPLY waiting for time files and check claimableAmount
        uint256 finalYieldDuration = _yieldDuration - _buyDuration * _targetSupply;
        uint256 checkPointDuration = 1 days;
        uint32 checkTime = uint32(finalYieldDuration / checkPointDuration);

        for (uint32 i = 0; i < checkTime; i++) {
            vm.warp(startBlockTime + _buyDuration * _targetSupply + i * checkPointDuration);
            // check max claimable amount
            uint256 currentClaimableAmount = _checkClaimableAmountAndFee();

            // once claimableAmount >  targetIncome
            if (currentClaimableAmount > TARGET_INCOME && reachTargetInDays == 0) {
                reachTargetInDays = uint8((i * _buyDuration) / (1 days));
                console.log("This params earn income after days: ", reachTargetInDays);
            }
        }

        uint256 claimableAmountAndFee = _checkClaimableAmountAndFee();

        income = claimableAmountAndFee;
    }

    function _checkClaimableAmountAndFee() public returns (uint256 v) {
        vm.prank(FACTORY_OWNER);
        uint256 depositedETHAmount = sharesFactory.depositedETHAmount();
        uint256 claimableAmount = aaveYieldAggregator.yieldMaxClaimable(depositedETHAmount);
        uint256 founderBalance = aWETH.balanceOf(SHARES_FOUNDER);

        v = claimableAmount + founderBalance;
        return v;
    }

    function _logSummary(string memory _filename, string memory _content) internal {
        string memory filename = _contactString("reports/", _filename, ".txt");
        _logToFile(filename, _content);
    }

    function _random(uint256 _seed, uint256 min, uint256 max) public view returns (uint256) {
        require(max > min, "max must be greater than min");
        uint256 randomHash = uint256(keccak256(abi.encodePacked(_seed,  block.timestamp, msg.sender)));
        return (randomHash % (max - min + 1)) + min;
    }

    function _random32(uint256 _seed, uint32 min, uint32 max) public view returns (uint32) {
        require(max > min, "max must be greater than min");
        return uint32(_random(_seed, min, max) % (2**32));
    }

    function _random96(uint256 _seed, uint96 min, uint96 max) public view returns (uint96) {
        require(max > min, "max must be greater than min");
        return uint96(_random(_seed, min, max) % (2**96));
    }

    function _random128(uint256 _seed, uint128 min, uint128 max) public view returns (uint128) {
        require(max > min, "max must be greater than min");
        return uint128(_random(_seed, min, max) % (2**128));
    }

    // TODO:
    function _logGraphData(string memory _filename, uint _x, uint _y) internal {
        string memory filename = _contactString("reports/", _filename, ".txt");
        _logToFile(filename, _contactString(_x.toString(), ",", _y.toString()));
    }
}
