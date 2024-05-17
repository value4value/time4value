// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { IAavePool, IAaveGateway } from "contracts/interface/IAave.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYieldAggregator } from "contracts/interface/IYieldAggregator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/Test.sol";

/**
 * @notice This contract is designed for Aave's ETH yield farming.
 */
contract AaveYieldAggregator is Ownable, IYieldAggregator, Test {
    using SafeERC20 for IERC20;

    address public immutable FACTORY;
    address public immutable WETH;
    uint256 public yieldBuffer = 1e12;

    IAavePool public immutable AAVE_POOL;
    IAaveGateway public immutable AAVE_WETH_GATEWAY;
    IERC20 public aWETH;

    uint256 internal constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 internal constant FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
    uint256 internal constant PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;

    constructor(address _factory, address _weth, address _aavePool, address _aaveGateway) {
        FACTORY = _factory;
        WETH = _weth;

        AAVE_WETH_GATEWAY = IAaveGateway(_aaveGateway);
        AAVE_POOL = IAavePool(_aavePool);

        aWETH = IERC20(AAVE_POOL.getReserveData(WETH).aTokenAddress);
        aWETH.safeApprove(address(AAVE_WETH_GATEWAY), type(uint256).max);
    }

    modifier onlyFactory() {
        require(msg.sender == FACTORY, "Only factory");
        _;
    }

    fallback() external payable { }

    receive() external payable { }

    /**
     * @notice Updates the yield buffer, which is used to cover rounding errors during withdrawals and deposits.
     * For more information, see: https://dev.pooltogether.com/protocol/reference/prize-vaults/PrizeVault#yieldbuffer
     */
    function setYieldBuffer(uint256 newYieldBuffer) external onlyOwner {
        yieldBuffer = newYieldBuffer;
    }

    /**
     * @notice Deposits ETH into the Aave and mints aToken for the factory.
     * Only callable by the factory contract.
     */
    function yieldDeposit() external onlyFactory {
        require(_checkAavePoolState(), "Aave paused");
        uint256 ethAmount = address(this).balance;
        if (ethAmount > 0) {
            AAVE_WETH_GATEWAY.depositETH{ value: ethAmount }(address(AAVE_POOL), FACTORY, 0);
        }
    }

    /**
     * @notice Withdraws ETH from the Aave and transfers it to the factory.
     * Only callable by the factory contract.
     */
    function yieldWithdraw(uint256 amount) external onlyFactory {
        require(_checkAavePoolState(), "Aave paused");
        if (amount > 0) {
            aWETH.safeTransferFrom(FACTORY, address(this), amount);
            AAVE_WETH_GATEWAY.withdrawETH(address(AAVE_POOL), amount, FACTORY);
        }
    }

    function yieldBalanceOf(address owner) external view returns (uint256 withdrawableETHAmount) {
        return aWETH.balanceOf(owner);
    }

    function yieldToken() external view returns (address yieldTokenAddr) {
        yieldTokenAddr = address(aWETH);
    }

    /**
     * @notice Calculate the maximum yield that the owner can claim.
     * @return maxClaimableETH max yield amount owner could get
     */
    function yieldMaxClaimable(uint256 depositedETHAmount) external view returns (uint256 maxClaimableETH) {
        uint256 withdrawableETHAmount = aWETH.balanceOf(FACTORY);
        maxClaimableETH = (withdrawableETHAmount - depositedETHAmount) < yieldBuffer
            ? 0
            : withdrawableETHAmount - depositedETHAmount - yieldBuffer;
        
        */
        uint256 withdrawableETHAmount = aWETH.balanceOf(MEST_FACTORY);

        try this._calculateMaxClaimableETH(withdrawableETHAmount, depositedETHAmount, yieldBuffer) returns (uint256 result) {
            maxClaimableETH = result;
        } catch Error(string memory reason){
           console.log("atoken error:", depositedETHAmount - withdrawableETHAmount); // 处理异常情况
        }
        
    }

    function _calculateMaxClaimableETH(uint256 _withdrawableETHAmount, uint256 _depositedETHAmount, uint256 _yieldBuffer) public pure returns (uint256) {
        if (_withdrawableETHAmount < _depositedETHAmount) {
            revert("withdrawableETHAmount is less than depositedETHAmount");
        }

        uint256 difference = _withdrawableETHAmount - _depositedETHAmount;

        if (difference < _yieldBuffer) {
            return 0;
        } else {
            return difference - _yieldBuffer;
        }
    }

    /**
     * @notice Check Aave pool state
     * @return bool true if Aave pool is active, false otherwise
     * @dev For more information, see:
     * https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/configuration/ReserveConfiguration.sol
     */
    function _checkAavePoolState() internal view returns (bool) {
        uint256 configData = AAVE_POOL.getReserveData(WETH).configuration.data;
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
