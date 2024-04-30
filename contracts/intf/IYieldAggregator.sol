// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IYieldAggregator {
    function yieldDeposit() external;
    function yieldWithdraw(uint256 amount) external;
    function yieldBalanceOf(address owner) external view returns(uint256 withdrawableETHAmount);
    function yieldToken() external view returns(address);
    function yieldMaxClaimable(uint256 depositedETHAmount) external view returns(uint256 maxClaimableETH);
}