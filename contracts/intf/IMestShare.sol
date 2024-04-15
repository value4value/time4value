/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

interface IMestShare {
    function shareMint(address to, uint256 id, uint256 amount) external;
    function shareBurn(address from, uint256 id, uint256 amount) external;
    function shareFromSupply(uint256 id) external view returns(uint256);
    function shareBalanceOf(address user, uint256 id) external view returns(uint256);
}