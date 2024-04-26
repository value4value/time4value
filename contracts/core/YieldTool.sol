/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: MIT

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

// Mest Factory 应无需关心 Yield 策略，调用 deposit, withdraw, claim 等方法即可
// 每次创建 share 时都会关联对应 Yield 策略地址和 ERC1155，以便后续寻找对应的 Yield 策略

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

    fallback() external payable {}

    receive() external payable {}

    // 重新设置 Aave 信息，似乎不如升级合约，或配置新的合约地址方便。
    // 因为如果更换 Aave 利息来源，可能就不一定继续在 Aave 上。
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

    // user buy share > mestFactory > yieldAggregator > [aave > aWETH] > mestFactory > ERC1155 > user
    // 为什么要从当前 balance 充值，而不是使用 amount 参数？
    function yieldDeposit(uint256 amount) external onlyFactory {
        uint256 subTotalPrice = address(this).balance;
        aaveGateway.depositETH{value: subTotalPrice}(address(aavePool), mestFactory, 0);
    }

    // user sell share > mestFactory > yieldAggregator > [aave > ETH] > mestFactory --> user
    function yieldWithdraw(uint256 amount) external onlyFactory {
        aWETH.transferFrom(mestFactory, address(this), amount);
        aaveGateway.withdrawETH(address(aavePool), amount, mestFactory);
    }

    // 采用 yieldToken 来读取 balance 会更好吗？
    function yieldBalanceOf(address owner) external returns(uint256 amount) {
        return aWETH.balanceOf(owner);
    }

    // yieldToken 是不是一个配置项会更好，比如在 Optimism 是 aWETH，在 CyberConnect 是 LRT
    function yieldToken() external returns(address yieldTokenAddr) {
        yieldTokenAddr = address(aWETH);
    }

    // 功能上与 yieldBalanceOf 重复
    function yieldMaxWithdrawable(address owner) external returns(uint256 amount) {
        return aWETH.balanceOf(owner);
    }
}