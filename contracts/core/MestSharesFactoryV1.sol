// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMestShare } from "../intf/IMestShare.sol";
import { IYieldAggregator } from "contracts/intf/IYieldAggregator.sol";
import { BondingCurveLib } from "../lib/BondingCurveLib.sol";

contract MestSharesFactoryV1 is Ownable {
    using SafeERC20 for IERC20;

    struct CurveFixedParam {
        uint256 basePrice;
        uint256 linearPriceSlope;
        uint256 inflectionPoint;
        uint256 inflectionPrice;
    }

    address public immutable mestERC1155;

    uint256 public shareIndex; 
    uint256 public depositedETHAmount;
    uint256 public referralFeePercent = 5 * 1e16;
    uint256 public creatorFeePercent = 5 * 1e16;

    CurveFixedParam public generalCurveFixedParam;
    IYieldAggregator public yieldAggregator;

    mapping(uint256 => address) public sharesMap;
    mapping(address => uint256[]) public creatorSharesMap; 

    event ClaimYield(uint256 amount, address indexed to);
    event Create(uint256 indexed shareId, address indexed creator);
    event Trade(
        address indexed trader,
        uint256 indexed shareId,
        bool isBuy,
        uint256 quantity,
        uint256 totalPrice,
        uint256 referralFee,
        uint256 creatorFee,
        uint256 newSupply
    );

    constructor(
        address _mestERC1155, 
        uint256 _basePrice, 
        uint256 _inflectionPoint, 
        uint256 _inflectionPrice,
        uint256 _linearPriceSlope
    ) {
        mestERC1155 = _mestERC1155;

        generalCurveFixedParam.basePrice = _basePrice; // 5000000000000000;
        generalCurveFixedParam.inflectionPoint = _inflectionPoint; // 1500;
        generalCurveFixedParam.inflectionPrice = _inflectionPrice; // 102500000000000000;
        generalCurveFixedParam.linearPriceSlope = _linearPriceSlope; // 0;
    }

    fallback() external payable {}

    receive() external payable {}

    function setReferralFeePercent(uint256 _feePercent) external onlyOwner {
        referralFeePercent = _feePercent;
    }

    function setCreatorFeePercent(uint256 _feePercent) external onlyOwner {
        creatorFeePercent = _feePercent;
    }

    /**
     * @notice Migrates the yieldAggregator.
     * There are three cases:
     * Case 1: address(0) -> yieldAggregator, which initializes yield farming.
     * Case 2: yieldAggregator -> blank yieldAggregator, which cancels yield farming.
     * Case 3: yieldAggregator -> new yieldAggregator, which migrates to a new yield farming.
     * @param _yieldAggregator The address of the yield aggregator.    
    */
    function migrate(address _yieldAggregator) external onlyOwner {
        require(_yieldAggregator != address(0), "Invalid yieldAggregator");

        // Case 1 if yieldAggregator is empty, else Case 2 or 3.
        if (address(yieldAggregator) == address(0)) {
            _setYieldAggregator(_yieldAggregator);
        } else {
            // Step 1: Withdraw all yieldToken into ETH.
            _withdrawAllYieldTokenToETH();

            // Step 2: Revoke the approval of the old yieldAggregator.
            address yieldToken = yieldAggregator.yieldToken();
            IERC20(yieldToken).safeApprove(address(yieldAggregator), 0);
            
            // Step 3: Set the new yieldAggregator.
            _setYieldAggregator(_yieldAggregator);

             // Step 4: Deposit all ETH into the new yieldAggregator as yieldToken.
            _depositAllETHToYieldToken();
        }
    }

    /**
     * @notice Only for owner to claim a specific yield amount.
     * @param amount The yield amount the owner claims.
     * @param to The address receiving the yield.
     */
    function claimYield(uint256 amount, address to) public onlyOwner {
        uint256 maxAmount = yieldAggregator.yieldMaxClaimable(depositedETHAmount);
        require(amount <= maxAmount, "Insufficient yield");

        yieldAggregator.yieldWithdraw(amount);
        _safeTransferETH(to, amount);

        emit ClaimYield(amount, to);
    }

    /**
     * @notice Creates a share with an auto-incremented ID.
     * @param creator The address of the creator, which will be used as creator fee recipient.
     * @dev The share ID is identical to the ERC1155 ID.
     */
    function createShare(address creator) public {
        sharesMap[shareIndex] = creator;
        creatorSharesMap[creator].push(shareIndex);

        emit Create(shareIndex, creator);

        shareIndex++;
    }

    /** 
     * @param shareId The ID of the share.
     * @param quantity The quantity of shares.
     * @param referral The address of the referral fee recipient.
     */
    function buyShare(uint256 shareId, uint256 quantity, address referral) public payable {
        require(address(yieldAggregator) != address(0), "Invalid yieldAggregator");
        require(shareId < shareIndex, "Invalid shareId");

        address creator = sharesMap[shareId];
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        (
            uint256 buyPriceAfterFee, 
            uint256 buyPrice, 
            uint256 referralFee, 
            uint256 creatorFee
        ) = getBuyPriceAfterFee(shareId, quantity, referral);

        require(fromSupply > 0 || msg.sender == creator, "First buyer must be creator");
        require(msg.value >= buyPriceAfterFee, "Insufficient payment");

        // Mint shares to the buyer
        IMestShare(mestERC1155).shareMint(msg.sender, shareId, quantity);
        emit Trade(
            msg.sender, 
            shareId, 
            true, 
            quantity, 
            buyPriceAfterFee, 
            referralFee, 
            creatorFee, 
            fromSupply + quantity
        );

        // Deposit the buy price (in ETH) to the yield aggregator (e.g., Aave)
        _safeTransferETH(address(yieldAggregator), buyPrice);
        yieldAggregator.yieldDeposit();
        depositedETHAmount += buyPrice;

        // Transfer referral and creator fees
        _safeTransferETH(referral, referralFee);
        _safeTransferETH(creator, creatorFee);

        // If buyer paid more than necessary, refund the excess
        uint256 refundAmount = msg.value - buyPriceAfterFee;
        if (refundAmount > 0) {
            _safeTransferETH(msg.sender, refundAmount);
        }
    }

    /** 
     * @param shareId The ID of the share.
     * @param quantity The quantity of shares.
     * @param minETHAmount The minmum amount of ETH will be used for slippage protection.
     * @param referral The address of the referral fee recipient.
     */
    function sellShare(uint256 shareId, uint256 quantity, uint256 minETHAmount, address referral) public payable {
        require(shareId < shareIndex, "Invalid shareId");
        require(IMestShare(mestERC1155).shareBalanceOf(msg.sender, shareId) >= quantity, "Insufficient shares");
        address creator = sharesMap[shareId];

        (
            uint256 sellPriceAfterFee, 
            uint256 sellPrice, 
            uint256 referralFee, 
            uint256 creatorFee
        ) = getSellPriceAfterFee(shareId, quantity, referral);
        require(sellPriceAfterFee >= minETHAmount, "Insufficient minReceive");

        // Burn shares from the seller
        IMestShare(mestERC1155).shareBurn(msg.sender, shareId, quantity);
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        emit Trade(
            msg.sender, 
            shareId, 
            false, 
            quantity, 
            sellPriceAfterFee, 
            referralFee, 
            creatorFee, 
            fromSupply
        );
        
        // Withdraw the sell price (in ETH) from the yield aggregator (e.g., Aave)
        yieldAggregator.yieldWithdraw(sellPrice);
        depositedETHAmount -= sellPrice;

        // Transfer ETH to the seller
        _safeTransferETH(msg.sender, sellPriceAfterFee);

        // Transfer referral and creator fees
        _safeTransferETH(referral, referralFee);
        _safeTransferETH(creator, creatorFee);
    }

    /**
     * @notice Calculates buy price and fees.
     * @return buyPriceAfterFee The amount user pay after fees.
     * @return buyPrice The initial price of the shares.
     * @return referralFee Fee by the referral. If = address(0), there is no referral fee.
     * @return creatorFee Fee by the share's creator.
    */
    function getBuyPriceAfterFee(uint256 shareId, uint256 quantity, address referral)
        public
        view
        returns (uint256 buyPriceAfterFee, uint256 buyPrice, uint256 referralFee, uint256 creatorFee)
    {
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        uint256 actualReferralFeePercent = referral != address(0) ? referralFeePercent : 0;

        buyPrice = _subTotal(fromSupply, quantity);
        referralFee = buyPrice * actualReferralFeePercent / 1 ether;
        creatorFee = buyPrice * creatorFeePercent / 1 ether;
        buyPriceAfterFee = buyPrice + referralFee + creatorFee;
    }

    /**
     * @notice Calculates sell price and fees.
     * @return sellPriceAfterFee The amount user receives after fees.
     * @return sellPrice The initial price of the shares.
     * @return referralFee Fee by the referral. If = address(0), there is no referral fee.
     * @return creatorFee Fee by the share's creator.
     */
    function getSellPriceAfterFee(uint256 shareId, uint256 quantity, address referral)
        public
        view
        returns (uint256 sellPriceAfterFee, uint256 sellPrice, uint256 referralFee, uint256 creatorFee)
    {
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        uint256 actualReferralFeePercent = referral != address(0) ? referralFeePercent : 0;

        sellPrice = _subTotal(fromSupply - quantity, quantity);
        referralFee = sellPrice * actualReferralFeePercent / 1 ether;
        creatorFee = sellPrice * creatorFeePercent / 1 ether;
        sellPriceAfterFee = sellPrice - referralFee - creatorFee;
    }

    /**
     * @notice Sets the yieldAggregator and approves it to spend the yieldToken.
     * @param _yieldAggregator The address of the yieldAggregator.
    */
    function _setYieldAggregator(address _yieldAggregator) internal {
        yieldAggregator = IYieldAggregator(_yieldAggregator);

        address yieldToken = yieldAggregator.yieldToken();
        IERC20(yieldToken).safeApprove(_yieldAggregator, type(uint256).max);
    }

    /**
     * @notice Withdraws all yieldToken into the MestSharesFactory as ETH.
     */
    function _withdrawAllYieldTokenToETH() internal {
        uint256 withdrawableETHAmount = yieldAggregator.yieldBalanceOf(address(this));
        yieldAggregator.yieldWithdraw(withdrawableETHAmount);
    }

    /**
     * @notice Deposits all ETH into the yieldAggregator as yieldToken.
     */
    function _depositAllETHToYieldToken() internal {
        uint256 ethAmount = address(this).balance;
        _safeTransferETH(address(yieldAggregator), ethAmount);
        yieldAggregator.yieldDeposit();
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
     * @notice Transfers ETH to the recipient address
     * @param to The destination of the transfer
     * @param value The value to be transferred
     * @dev Fails with `ETH transfer failed`
     */ 
    function _safeTransferETH(address to, uint256 value) internal {
        if (value > 0) {
            (bool success,) = to.call{value: value}(new bytes(0));
            require(success, "ETH transfer failed");
        }
    }
}
