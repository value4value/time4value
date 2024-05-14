// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { Test } from "forge-std/Test.sol";
import { BondingCurveLib } from "contracts/lib/BondingCurveLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

contract BondingCurveTests is Test {
    function test_sigmoid2Sum(uint128 inflectionPrice, uint32 fromSupply, uint32 quantity) public pure {
        uint32 inflectionPoint = uint32(type(uint32).max);
        quantity = uint32(_bound(quantity, 0, 256));
        uint256 sum = _sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity);
        assertEq(sum, _mockSigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity));
    }

    function test_sigmoidMultiPurchase(uint32 g, uint96 h, uint32 s, uint8 q) public pure {
        vm.assume(s <= type(uint32).max - q);

        uint256 sum;
        for (uint256 i = 0; i < q; ++i) {
            sum += _sigmoid2Sum(g, h, s + uint32(i), 1);
        }
        uint256 multi = _sigmoid2Sum(g, h, s, q);

        assertTrue(multi == sum);
    }

    function test_sigmoidMultiSell(uint32 g, uint96 h, uint32 s, uint8 q) public pure {
        vm.assume(s >= q);

        uint256 sum;
        for (uint256 i = 0; i < q; ++i) {
            sum += _sigmoid2Sum(g, h, s - uint32(i + 1), 1);
        }
        uint256 multi = _sigmoid2Sum(g, h, s - q, q);

        assertTrue(multi == sum);
    }

    // Check that the sum is monotonically increasing with the supply
    function test_sigmoidMonotony(uint32 g, uint96 h) public pure {
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

    function test_sigmoidBrutalized() public {
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

    function test_linearSum() public pure {
        uint256 sum = BondingCurveLib.linearSum(500000000000000, 0, 2);
        assertEq(sum, 1500000000000000);
    }

    function test_fromSupplyGreaterThanQuantity() public pure {
        // fromSupply + quantity + 1 > inflectionPoint
        uint256 sum = BondingCurveLib.sigmoid2Sum(1500, 500000000000000, 1500, 1);
        assertEq(sum, 500000000000000);
    }

    function test_fromSupplyLessThanQuantity() public pure {
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

    /// @dev Returns a pseudorandom random number from [0 .. 2**256 - 1] (inclusive).
    /// For usage in fuzz tests, please ensure that the function has an unnamed uint256 argument.
    /// e.g. `testSomething(uint256) public`.
    function _random() internal returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // This is the keccak256 of a very long string I randomly mashed on my keyboard.
            let sSlot := 0xd715531fe383f818c5f158c342925dcf01b954d24678ada4d07c36af0f20e1ee
            let sValue := sload(sSlot)

            mstore(0x20, sValue)
            r := keccak256(0x20, 0x40)

            // If the storage is uninitialized, initialize it to the keccak256 of the calldata.
            if iszero(sValue) {
                sValue := sSlot
                let m := mload(0x40)
                calldatacopy(m, 0, calldatasize())
                r := keccak256(m, calldatasize())
            }
            sstore(sSlot, add(r, 1))

            // Do some biased sampling for more robust tests.
            // prettier-ignore
            for { } 1 { } {
                let d := byte(0, r)
                // With a 1/256 chance, randomly set `r` to any of 0,1,2.
                if iszero(d) {
                    r := and(r, 3)
                    break
                }
                // With a 1/2 chance, set `r` to near a random power of 2.
                if iszero(and(2, d)) {
                    // Set `t` either `not(0)` or `xor(sValue, r)`.
                    let t := xor(not(0), mul(iszero(and(4, d)), not(xor(sValue, r))))
                    // Set `r` to `t` shifted left or right by a random multiple of 8.
                    switch and(8, d)
                    case 0 {
                        if iszero(and(16, d)) { t := 1 }
                        r := add(shl(shl(3, and(byte(3, r), 0x1f)), t), sub(and(r, 7), 3))
                    }
                    default {
                        if iszero(and(16, d)) { t := shl(255, 1) }
                        r := add(shr(shl(3, and(byte(3, r), 0x1f)), t), sub(and(r, 7), 3))
                    }
                    // With a 1/2 chance, negate `r`.
                    if iszero(and(0x20, d)) { r := not(r) }
                    break
                }
                // Otherwise, just set `r` to `xor(sValue, r)`.
                r := xor(sValue, r)
                break
            }
        }
    }

    /// @dev Alias to `_hem`.
    function _bound(uint256 x, uint256 min, uint256 max) internal pure virtual override returns (uint256 result) {
        result = _hem(x, min, max);
    }

    /// @dev Adapted from `bound`:
    /// https://github.com/foundry-rs/forge-std/blob/ff4bf7db008d096ea5a657f2c20516182252a3ed/src/StdUtils.sol#L10
    /// Differentially fuzzed tested against the original implementation.
    function _hem(uint256 x, uint256 min, uint256 max) internal pure virtual returns (uint256 result) {
        require(min <= max, "Max is less than min.");

        result = 0;
        /// @solidity memory-safe-assembly
        assembly {
            // prettier-ignore
            for { } 1 { } {
                // If `x` is between `min` and `max`, return `x` directly.
                // This is to ensure that dictionary values
                // do not get shifted if the min is nonzero.
                // More info: https://github.com/foundry-rs/forge-std/issues/188
                if iszero(or(lt(x, min), gt(x, max))) {
                    result := x
                    break
                }

                let size := add(sub(max, min), 1)
                if and(iszero(gt(x, 3)), gt(size, x)) {
                    result := add(min, x)
                    break
                }

                let w := not(0)
                if and(iszero(lt(x, sub(0, 4))), gt(size, sub(w, x))) {
                    result := sub(max, sub(w, x))
                    break
                }

                // Otherwise, wrap x into the range [min, max],
                // i.e. the range is inclusive.
                if iszero(lt(x, max)) {
                    let d := sub(x, max)
                    let r := mod(d, size)
                    if iszero(r) {
                        result := max
                        break
                    }
                    result := add(add(min, r), w)
                    break
                }
                let d := sub(min, x)
                let r := mod(d, size)
                if iszero(r) {
                    result := min
                    break
                }
                result := add(sub(max, r), 1)
                break
            }
        }
    }
}
