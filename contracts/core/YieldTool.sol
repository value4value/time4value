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
contract YieldTool is Ownable, IYieldTool {
    // for aave   
    address public immutable mestFactory;
    address public immutable WETH;
    uint256 public yieldBuffer = 1e12; 

    IAavePool public aavePool;
    IAaveGateway public aaveGateway;
    IAToken public aWETH;

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
        if(ethAmount > 0) {
            aaveGateway.depositETH{value: ethAmount}(address(aavePool), mestFactory, 0);
        }
    }

    // user sell share > mestFactory > yieldAggregator > [aave > ETH] > mestFactory --> user
    function yieldWithdraw(uint256 amount) external onlyFactory {
        if(amount > 0) {
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
}