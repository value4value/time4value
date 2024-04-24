/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../intf/IAave.sol";

interface IYieldTool {
    function yieldDeposit(uint256 amount) external;
    function yieldWithdraw(uint256 amount) external;
    function yieldBalanceOf(address owner) external returns(uint256);
    function yieldToken() external returns(address);
    function yieldMaxWithdrawable(address owner) external returns(uint256 amount);
}

contract YieldTool is Ownable, IYieldTool {
    // for aave   
    address public immutable mestFactory;
    address public immutable WETH;

    IAavePool public aavePool;
    IAaveGateway public aaveGateway;
    IAToken public aWETH;

    constructor(address _mestFactory, address _weth) public {
        mestFactory = _mestFactory;
        WETH = _weth;
    }

    modifier onlyFactory() {
        require(msg.sender == mestFactory, "Only factory");
        _;
    }

    // =============== eth =============

    fallback() external payable {}

    receive() external payable {}

    // ================= owner ================

    function setAaveInfo(address newPool, address newGateway) external onlyOwner {
        if(address(aWETH) != address(0)) {
            require(aWETH.balanceOf(mestFactory) == 0, "AToken didnt withdraw all");
            // revoke allowrance
            aWETH.approve(address(aaveGateway), 0);
        }
        aaveGateway = IAaveGateway(newGateway);
        aavePool = IAavePool(newPool);

        aWETH = IAToken(aavePool.getReserveData(WETH).aTokenAddress);
        aWETH.approve(address(aaveGateway), type(uint256).max);
    }

    // ============= yield function =========

    function yieldDeposit(uint256 amount) external onlyFactory {
        uint256 subTotalPrice = address(this).balance;
        aaveGateway.depositETH{value: subTotalPrice}(address(aavePool), mestFactory, 0);
    }

    function yieldWithdraw(uint256 amount) external onlyFactory {
        aWETH.transferFrom(mestFactory, address(this), amount);
        aaveGateway.withdrawETH(address(aavePool), amount, mestFactory);
    }

    function yieldBalanceOf(address owner) external returns(uint256 amount) {
        return aWETH.balanceOf(owner);
    }

    function yieldToken() external returns(address yieldTokenAddr) {
        yieldTokenAddr = address(aWETH);
    }

    function yieldMaxWithdrawable(address owner) external returns(uint256 amount) {
        return aWETH.balanceOf(owner);
    }
}