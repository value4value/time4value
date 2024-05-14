// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { TestPlus } from "../TestPlus.sol";
import { BondingCurveLib } from "contracts/lib/BondingCurveLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

contract BondingCurveTests is TestPlus {
    function testSigmoid2Sum(uint128 inflectionPrice, uint32 fromSupply, uint32 quantity) public pure {
        uint32 inflectionPoint = uint32(type(uint32).max);
        quantity = uint32(_bound(quantity, 0, 256));
        uint256 sum = _sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity);
        assertEq(sum, _mockSigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity));
    }

    function testSigmoidMultiPurchase(uint32 g, uint96 h, uint32 s, uint8 q) public pure {
        vm.assume(s <= type(uint32).max - q);

        uint256 sum;
        for (uint256 i = 0; i < q; ++i) {
            sum += _sigmoid2Sum(g, h, s + uint32(i), 1);
        }
        uint256 multi = _sigmoid2Sum(g, h, s, q);

        assertTrue(multi == sum);
    }

    function testSigmoidMultiSell(uint32 g, uint96 h, uint32 s, uint8 q) public pure {
        vm.assume(s >= q);

        uint256 sum;
        for (uint256 i = 0; i < q; ++i) {
            sum += _sigmoid2Sum(g, h, s - uint32(i + 1), 1);
        }
        uint256 multi = _sigmoid2Sum(g, h, s - q, q);

        assertTrue(multi == sum);
    }

    // Check that the sum is monotonically increasing with the supply
    function testSigmoidMonotony(uint32 g, uint96 h) public pure {
        unchecked {
            if (g < 3) g = 3;
            if (h == 0) h++;
            for (uint256 o; o < 8; ++o) {
                uint256 supply = g - 3 + o;
                if (supply < type(uint32).max) {
                    uint256 p0 = _sigmoid2Sum(g, h, uint32(supply), 1);
                    uint256 p1 = _sigmoid2Sum(g, h, uint32(supply + 1), 1);
                    assertTrue(p0 <= p1);
                }
            }
        }
    }

    function testSigmoidBrutalized() public {
        // Edge case tests
        // Test with inflection point at 0 and high inflection price
        _sigmoid2Brutalized(0, 5 * 1e16, 10, 1, 0);
        _sigmoid2Brutalized(5000, 0, 10, 1, 0);

        // Normal case tests where n < inflectionPoint
        // Test with various quantities and expected results
        _sigmoid2Brutalized(1500, 102500000000000000, 0, 1, 45555555555);
        _sigmoid2Brutalized(1500, 102500000000000000, 0, 2, 227777777775);
        _sigmoid2Brutalized(1500, 102500000000000000, 0, 3, 637777777770);
        _sigmoid2Brutalized(1500, 102500000000000000, 1498, 1, 102363378887640555);

        // Normal case tests where n = inflectionPoint
        // Note: s = 1499 and s = 1500 have the same result due to rounding issue
        _sigmoid2Brutalized(1500, 102500000000000000, 1499, 1, 102500000000000000);
        _sigmoid2Brutalized(1500, 102500000000000000, 1500, 1, 102500000000000000);
        _sigmoid2Brutalized(1500, 102500000000000000, 1499, 2, 205000000000000000);

        // Normal case tests where n > inflectionPoint
        // Test with various quantities and expected results
        _sigmoid2Brutalized(1500, 102500000000000000, 1501, 1, 102636666666666666);
        _sigmoid2Brutalized(1500, 102500000000000000, 1501, 2, 205409999999999999);
    }

    function testLinearSum() public pure {
        uint256 sum = BondingCurveLib.linearSum(500000000000000, 0, 2);
        assertEq(sum, 1500000000000000);
    }

    function testFromSupplyGreaterThanQuantity() public pure {
        // fromSupply + quantity + 1 > inflectionPoint
        uint256 sum = BondingCurveLib.sigmoid2Sum(1500, 500000000000000, 1500, 1);
        assertEq(sum, 500000000000000);
    }

    function testFromSupplyLessThanQuantity() public pure {
        uint256 sum = BondingCurveLib.sigmoid2Sum(1495, 500000000000000, 1497, 1);
        assertEq(sum, 501672240802675);
    }

    function _mockSigmoid2Sum(
        uint32 inflectionPoint,
        uint128 inflectionPrice,
        uint32 fromSupply,
        uint32 quantity
    ) internal pure returns (uint256 sum) {
        uint256 g = inflectionPoint;
        uint256 h = inflectionPrice;

        // Early return to save gas if either `g` or `h` is zero.
        if (g * h == 0) return 0;

        uint256 s = uint256(fromSupply) + 1;
        uint256 end = s + uint256(quantity);
        uint256 quadraticEnd = FixedPointMathLib.min(g, end);

        if (s < quadraticEnd) {
            uint256 a = FixedPointMathLib.rawDiv(h, g * g);
            do {
                sum += s * s * a;
            } while (++s != quadraticEnd);
        }

        if (s < end) {
            uint256 c = (3 * g) >> 2;
            uint256 h2 = h << 1;
            do {
                uint256 r = FixedPointMathLib.sqrt((s - c) * g);
                sum += FixedPointMathLib.rawDiv(h2 * r, g);
            } while (++s != end);
        }
    }

    function _sigmoid2Sum(
        uint32 inflectionPoint,
        uint128 inflectionPrice,
        uint32 supply,
        uint32 quantity
    ) internal pure returns (uint256) {
        return BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, supply, quantity);
    }

    function _sigmoid2Brutalized(
        uint32 inflectionPoint,
        uint96 inflectionPrice,
        uint32 supply,
        uint32 quantity,
        uint256 expectedResult
    ) internal {
        uint256 w = _random();
        assembly {
            inflectionPoint := or(inflectionPoint, shl(32, w))
            inflectionPrice := or(inflectionPrice, shl(96, w))
            supply := or(supply, shl(32, w))
            quantity := or(quantity, shl(32, w))
        }
        assertEq(_sigmoid2Sum(inflectionPoint, inflectionPrice, supply, quantity), expectedResult);
    }
}
