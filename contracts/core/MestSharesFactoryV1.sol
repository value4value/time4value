/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: MIT

*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IMestShare } from "../intf/IMestShare.sol";
import { IYieldAggregator } from "contracts/intf/IYieldAggregator.sol";
import { BondingCurveLib } from "../lib/BondingCurveLib.sol";

contract MestSharesFactoryV1 is Ownable {
    using SafeERC20 for IERC20;

    address public immutable mestERC1155;
    uint256 public shareIndex; 

    uint256 public referralFeePercent = 5 * 1e16;
    uint256 public creatorFeePercent = 5 * 1e16;
    CurveFixedParam public generalCurveFixedParam;

    mapping(uint256 => address) public sharesMap;
    mapping(address => uint256[]) public creatorSharesMap; 

    uint256 public depositedETHAmount; 
    IYieldAggregator public yieldAggregator;

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
        uint256 referralFee,
        uint256 creatorFee,
        uint256 newSupply
    );
    event ClaimYield(uint256 amount, address indexed to);

    constructor(
        address _mestERC1155, 
        uint256 _basePrice, 
        uint256 _inflectionPoint, 
        uint256 _inflectionPrice,
        uint256 _linearPriceSlope
    ) {
        mestERC1155 = _mestERC1155;

        generalCurveFixedParam.basePrice = _basePrice; //5000000000000000;
        generalCurveFixedParam.inflectionPoint = _inflectionPoint; //1500;
        generalCurveFixedParam.inflectionPrice = _inflectionPrice; //102500000000000000;
        generalCurveFixedParam.linearPriceSlope = _linearPriceSlope; //0;
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
     * @notice this function used for 3 cases for setting yieldAggregator
     * case 1 address(0) -> yieldAggregator
     * case 2 yieldAggregator -> blank yieldAggregator, which won't do yield farming
     * case 3 yieldAggregator -> new yieldAggregator
     * @param _yieldAggregator yield tool address    
     */
    function migrate(address _yieldAggregator) external onlyOwner {
        require(_yieldAggregator != address(0), "Invalid yieldAggregator");
        if(address(yieldAggregator) == address(0)) {
            _setYieldAggregator(_yieldAggregator);
        } else {
            // withdraw all yieldtoken
            _withdrawAllYieldTokenToETH();

            // revoke old yieldAggregator approve
            address yieldToken = yieldAggregator.yieldToken();
            IERC20(yieldToken).safeApprove(address(yieldAggregator), 0);
            
            // change yieldAggregator
            _setYieldAggregator(_yieldAggregator);

            // deposit all ETH
            _depositAllETHToYieldToken();
        }
    }

    /**
     * @notice only for owner to get certain amount yield
     * @param amount owner claim amount
     * @param to yield receiver address
     */
    function claimYield(uint256 amount, address to) public onlyOwner {
        uint256 maxAmount = yieldAggregator.yieldMaxClaimable(depositedETHAmount);
        require(amount <= maxAmount, "Invalid yield amount");
        yieldAggregator.yieldWithdraw(amount);
        _safeTransferETH(to, amount);

        emit ClaimYield(amount, to);
    }

    // =============== internal for migrate ===================

    function _setYieldAggregator(address _yieldAggregator) internal {
        // set yieldAggregator
        yieldAggregator = IYieldAggregator(_yieldAggregator);

        // yield token approve for yieldAggregator
        address yieldToken = yieldAggregator.yieldToken();
        IERC20(yieldToken).safeApprove(_yieldAggregator, type(uint256).max);
    }

    function _withdrawAllYieldTokenToETH() internal {
        uint256 withdrawableETHAmount = yieldAggregator.yieldBalanceOf(address(this));
        yieldAggregator.yieldWithdraw(withdrawableETHAmount);
    }

    function _depositAllETHToYieldToken() internal {
        uint256 ethAmount = address(this).balance;
        _safeTransferETH(address(yieldAggregator), ethAmount);
        yieldAggregator.yieldDeposit();
    }

    // ==================== public =======================

    /**
     * @notice Calculates buy price and fees.
     * @return buyPriceAfterFee Amount user pay after fees.
     * @return buyPrice Price of shares before fees.
     * @return referralFee Fee by the protocol. If = address(0), there is no referral fee.
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
     * @return sellPriceAfterFee Amount user receives after fees.
     * @return sellPrice Price of shares before fees.
     * @return referralFee Fee by the protocol. If = address(0), there is no referral fee.
     * @return creatorFee Fee by the share's creator.
     */
    function getSellPriceAfterFee(uint256 shareId, uint256 quantity, address referral)
        public
        view
        returns (uint256 sellPriceAfterFee, uint256 sellPrice, uint256 referralFee, uint256 creatorFee)
    {
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        uint256 actualReferralFeePercent = referral != address(0) ? referralFeePercent : 0;
        require(fromSupply >= quantity, "Exceeds supply");

        sellPrice = _subTotal(fromSupply - quantity, quantity);
        referralFee = sellPrice * actualReferralFeePercent / 1 ether;
        creatorFee = sellPrice * creatorFeePercent / 1 ether;
        sellPriceAfterFee = sellPrice - referralFee - creatorFee;
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
        sharesMap[shareIndex] = creator;
        creatorSharesMap[creator].push(shareIndex);

        emit Create(shareIndex, creator);

        shareIndex++;
    }

    /** 
     * @param shareId the id of share 
     * @param quantity the quantity of share
     * @param referral referral fee receiver
     * @dev in this case, slippage protection use msg.value insufficient
     */
    function buyShare(uint256 shareId, uint256 quantity, address referral) public payable {
        require(address(yieldAggregator) != address(0), "Invalid yieldAggregator");
        require(shareId < shareIndex, "Invalid shareId");
        address creator = sharesMap[shareId];
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        
        // Anti-frontrunining, first buyer must be creator
        require(fromSupply > 0 || msg.sender == creator, "First buyer must be creator");

        (uint256 buyPriceAfterFee, uint256 buyPrice, uint256 referralFee, uint256 creatorFee) = getBuyPriceAfterFee(shareId, quantity, referral);
        require(msg.value >= buyPriceAfterFee, "Insufficient payment");
        IMestShare(mestERC1155).shareMint(msg.sender, shareId, quantity);
        emit Trade(
            msg.sender, shareId, true, quantity, buyPriceAfterFee, referralFee, creatorFee, fromSupply + quantity
        );

        // pay fee
        _safeTransferETH(referral, referralFee);
        _safeTransferETH(creator, creatorFee);

        // refund if paid more than necessary
        uint256 refundAmount = msg.value - buyPriceAfterFee;
        if (refundAmount > 0) {
            _safeTransferETH(msg.sender, refundAmount);
        }

        // deposit to yield aggregator, e.g. Aave
        _safeTransferETH(address(yieldAggregator), buyPrice);
        yieldAggregator.yieldDeposit();
        depositedETHAmount += buyPrice;
    }

    /**
     * @param shareId the id of share
     * @param quantity the quantity of share
     * @param minETHAmount minimum amount of ETH that a user receives, used for slippage protection. If the amount is less than this ETH value, it will revert.
     * @param referral referral fee receiver
     */
    function sellShare(uint256 shareId, uint256 quantity, uint256 minETHAmount, address referral) public payable {
        require(shareId < shareIndex, "Invalid shareId");
        require(IMestShare(mestERC1155).shareBalanceOf(msg.sender, shareId) >= quantity, "Insufficient shares");
        address creator = sharesMap[shareId];

        (uint256 sellPriceAfterFee, uint256 sellPrice, uint256 referralFee, uint256 creatorFee) = getSellPriceAfterFee(shareId, quantity, referral);
        require(sellPriceAfterFee >= minETHAmount, "Insufficient minReceive");
        IMestShare(mestERC1155).shareBurn(msg.sender, shareId, quantity);
        uint256 fromSupply = IMestShare(mestERC1155).shareFromSupply(shareId);
        emit Trade(msg.sender, shareId, false, quantity, sellPriceAfterFee, referralFee, creatorFee, fromSupply);

        // withdraw from yield aggregator, e.g. Aave
        yieldAggregator.yieldWithdraw(sellPrice);
        depositedETHAmount -= sellPrice;

        // unstake ETH to user
        _safeTransferETH(msg.sender, sellPriceAfterFee);

        // pay fee
        _safeTransferETH(referral, referralFee);
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
