// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import { BondingCurveLib } from "contracts/lib/BondingCurveLib.sol";
import { FixedPointMathLib } from "contracts/lib/FixedPointMathLib.sol";

contract BondingCurveHelper {
    function sigmoid2Sum(
        uint256 inflectionPoint,
        uint256 inflectionPrice,
        uint256 fromSupply,
        uint256 quantity
    ) public pure returns (uint256) {
        uint256 sum = BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity);
        return sum;
    }

    function locSigmoid2Sum(
        uint256 inflectionPoint,
        uint256 inflectionPrice,
        uint256 fromSupply,
        uint256 quantity
    ) public returns (uint256 sum) {
        unchecked {
            uint256 g = inflectionPoint;
            uint256 h = inflectionPrice;

            // Early return to save gas if either `g` or `h` is zero.
            if (g * h == 0) return 0;

            uint256 s = uint256(fromSupply) + 1;
            uint256 end = s + uint256(quantity);
            uint256 quadraticEnd = FixedPointMathLib.min(g, end);

            if (s < quadraticEnd) {
                uint256 k = uint256(fromSupply); // `s - 1`.
                uint256 n = quadraticEnd - 1;
                // In practice, `h` (units: wei) will be set to be much greater than `g * g`.
                uint256 a = FixedPointMathLib.rawDiv(h, g * g);
                // Use the closed form to compute the sum.
                // sum(i ^2)/ g^2 considered as infinitesimal and use taylor series
                sum = ((n * (n + 1) * ((n << 1) + 1) - k * (k + 1) * ((k << 1) + 1)) / 6) * a;
                s = quadraticEnd;
            }
            //console.log("part1:", sum);

            if (s < end) {
                uint256 c = (3 * g) >> 2;
                uint256 h2 = h << 1;
                do {
                    //console.log("s - c:", s-c);
                    uint256 r = FixedPointMathLib.sqrt((s - c) * g);
                    //console.log("r:", r);
                    sum += FixedPointMathLib.rawDiv(h2 * r, g);
                } while (++s != end);
            }
            //console.log("part2:", sum);
        }
    }

    function linearSum(
        uint256 linearPriceSlope,
        uint256 fromSupply,
        uint256 quantity
    ) public pure returns (uint256) {
        uint256 sum = BondingCurveLib.linearSum(linearPriceSlope, fromSupply, quantity);
        return sum;
    }
}

contract BondingCurveTests is Test {
    BondingCurveHelper public helper;

    function setUp() public {
        helper = new BondingCurveHelper();
    }

    function testSigmoid2Sum() public {
        uint256 sum = helper.sigmoid2Sum(0, 5 * 1e16, 10, 1);
        assertEq(sum, 0);

        sum = helper.sigmoid2Sum(5000, 0, 10, 1);
        assertEq(sum, 0);

        // normal test, n < inflectionPoint
        sum = helper.sigmoid2Sum(1500, 102500000000000000, 0, 1);
        assertEq(sum, 45555555555);

        sum = helper.sigmoid2Sum(1500, 102500000000000000, 0, 2);
        assertEq(sum, 227777777775);

        sum = helper.sigmoid2Sum(1500, 102500000000000000, 0, 3);
        assertEq(sum, 637777777770);

        sum = helper.sigmoid2Sum(1500, 102500000000000000, 1498, 1);
        assertEq(sum, 102363378887640555);

        // normal test, n = inflectionPoint
        sum = helper.sigmoid2Sum(1500, 102500000000000000, 1499, 1);
        assertEq(sum, 102500000000000000);

        // notice, s = 1499 and s = 1500 have the same result because of sqrt error
        // this is not included in bugs
        sum = helper.locSigmoid2Sum(1500, 102500000000000000, 1500, 1);
        assertEq(sum, 102500000000000000);

        sum = helper.locSigmoid2Sum(1500, 102500000000000000, 1499, 2);
        assertEq(sum, 205000000000000000);

        // normal test, n > inflectionPoint
        sum = helper.sigmoid2Sum(1500, 102500000000000000, 1501, 1);
        assertEq(sum, 102636666666666666);

        sum = helper.sigmoid2Sum(1500, 102500000000000000, 1501, 2);
        assertEq(sum, 205409999999999999);
    }

    function testLinearSum() public {
        uint256 sum = helper.linearSum(500000000000000, 0, 2);
        assertEq(sum, 1500000000000000);
    }
}
