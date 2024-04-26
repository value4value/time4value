/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: MIT

*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMestShare } from "../intf/IMestShare.sol";
import { IYieldTool } from "./YieldTool.sol";
import { BondingCurveLib } from "../lib/BondingCurveLib.sol";

contract MestSharesFactoryV1 is Ownable {
    using SafeERC20 for IERC20;

    address public immutable mestERC1155;
    uint256 public shareTypeNumber; // 命名 shareIndex 会更好理解一些 

    address public protocolFeeReceiver; // 移除 protocol fee, 在 trade 时设置 referral receiver 会更合适
    uint256 public protocolFeePercent = 5 * 1e16;
    uint256 public creatorFeePercent = 5 * 1e16;
    CurveFixedParam public generalCurveFixedParam;

    mapping(uint256 => address) public sharesMap;
    mapping(address => uint256[]) public creatorSharesMap; // 该变量可以考虑移除，因为 sharemap 也能计算出该数据

    uint256 public depositedTotalAmount; // ETH 数量是不是可以通过 supply 计算出来？_subTotal(0, supply)
    uint256 public yieldBuffer = 1e12; // 该变量放在 yield 合约地址会更合适
    IYieldTool public yieldTool;

    struct CurveFixedParam {
        uint256 basePrice;
        uint256 linearPriceSlope;
        uint256 inflectionPoint;
        uint256 inflectionPrice;
    }

    event Create(uint256 indexed shareId, address indexed creator);
    event Trade(
        address indexed user,
        uint256 indexed share,
        bool isBuy,
        uint256 quantity,
        uint256 totalPrice,
        uint256 protocolFee,
        uint256 creatorFee,
        uint256 newSupply
    );

    constructor(address _protocolFeeReceiver, address _mestERC1155) {
        protocolFeeReceiver = _protocolFeeReceiver;
        mestERC1155 = _mestERC1155;

        // curver 参数允许初始化时配置
        generalCurveFixedParam.basePrice = 5000000000000000;
        generalCurveFixedParam.inflectionPoint = 1500;
        generalCurveFixedParam.inflectionPrice = 102500000000000000;
        generalCurveFixedParam.linearPriceSlope = 0;
    }

    fallback() external payable {}

    receive() external payable {}

    function setProtocolFeeReceiver(address newReceiver) external onlyOwner {
        protocolFeeReceiver = newReceiver;
    }

    function setProtocolFeePercent(uint256 _feePercent) external onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setCreatorFeePercent(uint256 _feePercent) external onlyOwner {
        creatorFeePercent = _feePercent;
    }

    // 如果已创建的 share 不能更换 yield 策略，那么是否不需要如此处理
    // 新创建的 share 允许配置新的 yield 策略
    function setYieldTool(address _yieldTool) external onlyOwner {
        // check remove condition
        if(address(yieldTool) != address(0)) {
            uint256 yieldBal = yieldTool.yieldBalanceOf(address(this));
            require(yieldBal == 0, "Yield token didnt withdraw all");

            // revoke approve
            address yieldToken = yieldTool.yieldToken();
            IERC20(yieldToken).approve(address(yieldTool), 0);
        }

        // change yieldTool
        yieldTool = IYieldTool(_yieldTool);

        // yield token approve for
        address yieldToken = yieldTool.yieldToken();
        IERC20(yieldToken).approve(_yieldTool, type(uint256).max);
    }

    // 放在 yield 策略更合适
    function setYieldBuffer(uint256 newYieldBuffer) external onlyOwner {
        yieldBuffer = newYieldBuffer;
    }

    // 放在 yield 策略更合适, claimYield 调用该方法即可
    /**
     * @notice Calculate the maximum yield that the owner can claim.
     * @return maxYieldAmount max yield amount owner could get
     */
    function maxClaimableYield() public returns(uint256 maxYieldAmount) {
        uint256 withdrawableAmount = yieldTool.yieldBalanceOf(address(this));
        maxYieldAmount = (withdrawableAmount - depositedTotalAmount) < yieldBuffer ? 0 : withdrawableAmount - depositedTotalAmount - yieldBuffer;
    }

    /**
     * @notice only for owner to get certain amount yield
     * @param amount owner claim amount
     * @param to yield receiver address
     */
    function claimYield(uint256 amount, address to) public onlyOwner {
        uint256 maxAmount = maxClaimableYield();
        require(amount <= maxAmount, "Invalid yield amount");
        yieldTool.yieldWithdraw(amount);
        _safeTransferETH(to, amount);
    }

    // migrate 放在 yield 合约中，也可以考虑有没有比 migrare 更好的方法
    function withdrawAllAtokenToETH() external onlyOwner {
        uint256 withdrawableAmount = yieldTool.yieldMaxWithdrawable(address(this));
        yieldTool.yieldWithdraw(withdrawableAmount);
    }

    function depositAllETHToAToken() external onlyOwner {
        uint256 ethAmount = address(this).balance;
        _safeTransferETH(address(yieldTool), ethAmount);
        yieldTool.yieldDeposit(ethAmount);
    }

    /**
     * @notice Calculates buy price and fees.
     * @return total Amount user pay after fees.
     * @return subTotal Price of shares before fees.
     * @return protocolFee Fee by the protocol.
     * @return creatorFee Fee by the share's creator.
    */
    function getBuyPriceAfterFee(uint256 shareId, uint256 quantity)
        public
        view
        returns (uint256 total, uint256 subTotal, uint256 protocolFee, uint256 creatorFee)
    {
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);

        subTotal = _subTotal(fromSupply, quantity);
        protocolFee = subTotal * protocolFeePercent / 1 ether;
        creatorFee = subTotal * creatorFeePercent / 1 ether;
        total = subTotal + protocolFee + creatorFee;
    }

    /**
     * @notice Calculates sell price and fees.
     * @return total Amount user receives after fees.
     * @return subTotal Price of shares before fees.
     * @return protocolFee Fee by the protocol.
     * @return creatorFee Fee by the share's creator.
     */
    function getSellPriceAfterFee(uint256 shareId, uint256 quantity)
        public
        view
        returns (uint256 total, uint256 subTotal, uint256 protocolFee, uint256 creatorFee)
    {
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        require(fromSupply >= quantity, "Exceeds supply");

        subTotal = _subTotal(fromSupply - quantity, quantity);
        protocolFee = subTotal * protocolFeePercent / 1 ether;
        creatorFee = subTotal * creatorFeePercent / 1 ether;
        total = subTotal - protocolFee - creatorFee;
    }

    /**
     * @dev Returns the area under the bonding curve, which is the price before any fees.
     * @param fromSupply The starting share supply.
     * @param quantity The number of shares to be minted.
     * @return subTotal The area under the bonding curve.
     */
    function _subTotal(uint256 fromSupply, uint256 quantity) internal view returns (uint256 subTotal) {
        unchecked {
            subTotal = generalCurveFixedParam.basePrice * quantity;
            subTotal += BondingCurveLib.linearSum(generalCurveFixedParam.linearPriceSlope, fromSupply, quantity);
            subTotal += BondingCurveLib.sigmoid2Sum(
                generalCurveFixedParam.inflectionPoint, generalCurveFixedParam.inflectionPrice, fromSupply, quantity
            );
        }
    }

    /**
     * @notice Create share with incremented id
     * @param creator Set the creator's address, which will be used as a fee address
     * @dev Share id is same as ERC1155 id
     */
    function createShare(address creator) public {
        sharesMap[shareTypeNumber] = creator;
        creatorSharesMap[creator].push(shareTypeNumber);

        emit Create(shareTypeNumber, creator);

        shareTypeNumber++;
    }

    /** 
     * @param shareId the id of share 
     * @param quantity the quantity of share
     * @dev in this case, slippage protection use msg.value insufficient
     */
    function buyShare(uint256 shareId, uint256 quantity) public payable {
        require(address(yieldTool) != address(0), "Invalid yieldTool");
        require(shareId < shareTypeNumber, "Invalid shareId");
        address creator = sharesMap[shareId];
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        
        // Anti-frontrunining, first buyer must be creator
        require(fromSupply > 0 || msg.sender == creator, "First buyer must be creator");

        (uint256 totalPrice, uint256 subTotalPrice, uint256 protocolFee, uint256 creatorFee) = getBuyPriceAfterFee(shareId, quantity);
        require(msg.value >= totalPrice, "Insufficient payment");
        IMestShare(mestERC1155).shareMint(msg.sender, shareId, quantity);
        emit Trade(
            msg.sender, shareId, true, quantity, totalPrice, protocolFee, creatorFee, fromSupply + quantity
        );

        // pay fee
        _safeTransferETH(protocolFeeReceiver, protocolFee);
        _safeTransferETH(creator, creatorFee);

        // refund if paid more than necessary
        uint256 refundAmount = msg.value - totalPrice;
        if (refundAmount > 0) {
            _safeTransferETH(msg.sender, refundAmount);
        }

        // deposit to yield aggregator, e.g. Aave
        _safeTransferETH(address(yieldTool), subTotalPrice);
        yieldTool.yieldDeposit(subTotalPrice);
        depositedTotalAmount += subTotalPrice;
    }

    /**
     * @param shareId the id of share
     * @param quantity the quantity of share
     * @param minETHAmount minimum amount of ETH that a user receives, used for slippage protection. If the amount is less than this ETH value, it will revert.
     */
    function sellShare(uint256 shareId, uint256 quantity, uint256 minETHAmount) public payable {
        require(address(yieldTool) != address(0), "Invalid yieldTool");
        require(shareId < shareTypeNumber, "Invalid shareId");
        require(IMestShare(mestERC1155).shareBalanceOf(msg.sender, shareId) >= quantity, "Insufficient shares");
        address creator = sharesMap[shareId];

        (uint256 totalPrice, uint256 subTotalPrice, uint256 protocolFee, uint256 creatorFee) = getSellPriceAfterFee(shareId, quantity);
        require(totalPrice >= minETHAmount, "Insufficient minReceive");
        IMestShare(mestERC1155).shareBurn(msg.sender, shareId, quantity);
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        emit Trade(msg.sender, shareId, false, quantity, totalPrice, protocolFee, creatorFee, fromSupply);

        // withdraw from yield aggregator, e.g. Aave
        yieldTool.yieldWithdraw(subTotalPrice);
        depositedTotalAmount -= subTotalPrice;

        // unstake ETH to user
        _safeTransferETH(msg.sender, totalPrice);

        // pay fee
        _safeTransferETH(protocolFeeReceiver, protocolFee);
        _safeTransferETH(creator, creatorFee);
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
