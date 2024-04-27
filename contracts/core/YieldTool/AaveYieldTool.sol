/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: MIT

*/

pragma solidity 0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/intf/IAave.sol";
import { IYieldTool } from "contracts/intf/IYieldTool.sol";

/**
 * @notice YieldTool for Aave
 * Mest Factory needn't care about Yield Strategy，only call deposit(), withdraw(), claim()...
 */ 
contract AaveYieldTool is Ownable, IYieldTool {
    using SafeERC20 for IERC20;

    // for aave   
    address public immutable mestFactory;
    address public immutable WETH;
    uint256 public yieldBuffer = 1e12; 

    IAavePool public aavePool;
    IAaveGateway public aaveGateway;
    IERC20 public aWETH;

    uint256 internal constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
    uint256 internal constant PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;

    constructor(address _mestFactory, address _weth, address _aavePool, address _aaveGateway) {
        mestFactory = _mestFactory;
        WETH = _weth;

        aaveGateway = IAaveGateway(_aaveGateway);
        aavePool = IAavePool(_aavePool);

        aWETH = IERC20(aavePool.getReserveData(WETH).aTokenAddress);
        aWETH.safeApprove(address(aaveGateway), type(uint256).max);
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
    function yieldDeposit() external onlyFactory {
        require(_checkAavePoolState(), "Aave paused");
        uint256 ethAmount = address(this).balance;
        if(ethAmount > 0) {
            aaveGateway.depositETH{value: ethAmount}(address(aavePool), mestFactory, 0);
        }
    }

    // user sell share > mestFactory > yieldAggregator > [aave > ETH] > mestFactory --> user
    function yieldWithdraw(uint256 amount) external onlyFactory {
        require(_checkAavePoolState(), "Aave paused");
        if(amount > 0) {
            aWETH.safeTransferFrom(mestFactory, address(this), amount);
            aaveGateway.withdrawETH(address(aavePool), amount, mestFactory);
        }
    }

    function yieldBalanceOf(address owner) external view returns(uint256 withdrawableETHAmount) {
        return aWETH.balanceOf(owner);
    }

    function yieldToken() external view returns(address yieldTokenAddr) {
        yieldTokenAddr = address(aWETH);
    }

    /**
     * @notice Calculate the maximum yield that the owner can claim.
     * @return maxClaimableETH max yield amount owner could get
     */
    function yieldMaxClaimable(uint256 depositedETHAmount) external view returns(uint256 maxClaimableETH) {
        uint256 withdrawableETHAmount = aWETH.balanceOf(mestFactory);
        maxClaimableETH = (withdrawableETHAmount - depositedETHAmount) < yieldBuffer ? 0 : withdrawableETHAmount - depositedETHAmount - yieldBuffer;
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
}