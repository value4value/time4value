pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

contract LogUtil is Test {
    function _contactString(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    function _contactString(string memory a, string memory b, string memory c) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f, g));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f, g, h));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h,
        string memory i
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f, g, h, i));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h,
        string memory i,
        string memory j
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f, g, h, i, j));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h,
        string memory i,
        string memory j,
        string memory k
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f, g, h, i, j, k));
    }

    function _contactString(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e,
        string memory f,
        string memory g,
        string memory h,
        string memory i,
        string memory j,
        string memory k,
        string memory l
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e, f, g, h, i, j, k, l));
    }

    function test() public {}
}
