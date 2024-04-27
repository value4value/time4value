/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: MIT

*/

pragma solidity 0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../intf/IAave.sol";

interface IYieldTool {
    function yieldDeposit(uint256) external;
    function yieldWithdraw(uint256 amount) external;
    function yieldBalanceOf(address owner) external view returns(uint256 underlyingAmount);
    function yieldToken() external view returns(address);
    function yieldMaxClaimable(uint256 depositedAmount) external view returns(uint256 maxUnderlyingAmount);
}

/**
 * @notice Mest Factory needn't care about Yield Strategy，only call deposit(), withdraw(), claim()...
 */ 

 //todo 考虑：undercollateralized（aave导致坏账）

contract YieldTool is Ownable, IYieldTool {
    // for aave   
    address public immutable mestFactory;
    address public immutable WETH;
    uint256 public yieldBuffer = 1e12; 

    IAavePool public aavePool;
    IAaveGateway public aaveGateway;
    IAToken public aWETH;

    uint256 internal constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
    uint256 internal constant PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;

    constructor(address _mestFactory, address _weth, address _aavePool, address _aaveGateway) {
        mestFactory = _mestFactory;
        WETH = _weth;

        aaveGateway = IAaveGateway(_aaveGateway);
        aavePool = IAavePool(_aavePool);

        aWETH = IAToken(aavePool.getReserveData(WETH).aTokenAddress);
        aWETH.approve(address(aaveGateway), type(uint256).max);
    }

    modifier onlyFactory() {
        require(msg.sender == mestFactory, "Only factory");
        _;
    }

    fallback() external payable {}

    receive() external payable {}

    function setYieldBuffer(uint256 newYieldBuffer) external onlyOwner {
        yieldBuffer = newYieldBuffer;
    }

    // ================== yield interface ==================

    // user buy share > mestFactory > yieldAggregator > [aave > aWETH] > mestFactory > ERC1155 > user
    function yieldDeposit(uint256) external onlyFactory {
        uint256 ethAmount = address(this).balance;
        if(_checkAavePoolState()) {   
            if(ethAmount > 0) {
                aaveGateway.depositETH{value: ethAmount}(address(aavePool), mestFactory, 0);
            }
        }
        else {
            _safeTransferETH(mestFactory, ethAmount);
        }
    }
    // if aave is paused mest not
    // eth 正常buy and sell
    // 之前的钱 如果没提
    // 如果此时有一些 eth剩余在合约里，aave正常后是不是能单独deposit进去

    // user sell share > mestFactory > yieldAggregator > [aave > ETH] > mestFactory --> user
    function yieldWithdraw(uint256 amount) external onlyFactory {
        if(amount > 0 && _checkAavePoolState()) {
            aWETH.transferFrom(mestFactory, address(this), amount);
            aaveGateway.withdrawETH(address(aavePool), amount, mestFactory);
        }
    }

    function yieldBalanceOf(address owner) external view returns(uint256 underlyingAmount) {
        return aWETH.balanceOf(owner);
    }

    function yieldToken() external view returns(address yieldTokenAddr) {
        yieldTokenAddr = address(aWETH);
    }

    /**
     * @notice Calculate the maximum yield that the owner can claim.
     * @return maxUnderlyingAmount max yield amount owner could get
     */
    function yieldMaxClaimable(uint256 depositedTotalAmount) external view returns(uint256 maxUnderlyingAmount) {
        uint256 withdrawableAmount = aWETH.balanceOf(mestFactory);
        maxUnderlyingAmount = (withdrawableAmount - depositedTotalAmount) < yieldBuffer ? 0 : withdrawableAmount - depositedTotalAmount - yieldBuffer;
    }

    // ================= internal ====================

    function _checkAavePoolState() internal view returns(bool) {
        // check if asset is paused
        uint256 configData = aavePool.getReserveData(WETH).configuration.data;
        if (!(_getActive(configData) && !_getFrozen(configData) && !_getPaused(configData))) {
            return false;
        }
        return true;
    }

    function _getActive(uint256 configData) internal pure returns (bool) {
        return configData & ~ACTIVE_MASK != 0;
    }

    function _getFrozen(uint256 configData) internal pure returns (bool) {
        return configData & ~FROZEN_MASK != 0;
    }

    function _getPaused(uint256 configData) internal pure returns (bool) {
        return configData & ~PAUSED_MASK != 0;
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