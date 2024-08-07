// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { IAavePool, IAaveGateway } from "contracts/interface/IAave.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IYieldAggregator } from "contracts/interface/IYieldAggregator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice This contract is designed for Aave's ETH yield farming.
 */
contract AaveYieldAggregator is Ownable, IYieldAggregator {
    using SafeERC20 for IERC20;

    address public immutable FACTORY;
    address public immutable WETH;
    uint256 public yieldBuffer = 1e12;

    IAavePool public immutable AAVE_POOL;
    IAaveGateway public immutable AAVE_WETH_GATEWAY;
    IERC20 public aWETH;

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
        if (withdrawableETHAmount <= depositedETHAmount + yieldBuffer) {
            return 0;
        } else {
            return withdrawableETHAmount - depositedETHAmount - yieldBuffer;
        }
    }
}
