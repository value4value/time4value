// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { IYieldAggregator } from "contracts/intf/IYieldAggregator.sol";

/**
 * @notice This is an empty contract, i.e., it does not do any yield farming as a fallback.
 */ 
contract BlankYieldAggregator is IYieldAggregator {

    address public immutable mestFactory;
    address public immutable WETH;

    constructor(address _mestFactory, address _weth) {
        mestFactory = _mestFactory;
        WETH = _weth;
    }

    modifier onlyFactory() {
        require(msg.sender == mestFactory, "Only factory");
        _;
    }

    fallback() external payable {}

    receive() external payable {}

    function yieldDeposit() external onlyFactory {
        _safeTransferETH(mestFactory, address(this).balance);
    }

    function yieldWithdraw(uint256) external onlyFactory {
    }

    function yieldBalanceOf(address) external pure returns(uint256 withdrawableETHAmount) {
        return 0;
    }

    function yieldToken() external view returns(address yieldTokenAddr) {
        return WETH;
    }

    function yieldMaxClaimable(uint256) external pure returns(uint256 maxClaimableETH) {
        return 0;
    }


    /** 
     * @notice Transfers ETH to the recipient address
     * @param to The destination of the transfer
     * @param value The value to be transferred
     * @dev Fails with `Eth transfer failed`
     */ 
    function _safeTransferETH(address to, uint256 value) internal {
        if (value > 0) {
            (bool success,) = to.call{value: value}(new bytes(0));
            require(success, "Eth transfer failed");
        }
    }
}