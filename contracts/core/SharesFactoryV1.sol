// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IShare } from "../interface/IShare.sol";
import { IYieldAggregator } from "contracts/interface/IYieldAggregator.sol";
import { BondingCurveLib } from "../lib/BondingCurveLib.sol";

contract SharesFactoryV1 is Ownable2Step {
    using SafeERC20 for IERC20;

    struct Curve {
        uint96 basePrice;
        uint128 linearPriceSlope;
        uint32 inflectionPoint;
        uint128 inflectionPrice;
        bool exists;
    }

    struct Share {
        address creator;
        uint8 curveType;
    }

    mapping(uint256 shareId => Share share) public sharesMap;
    mapping(uint8 curveType => Curve curve) public curvesMap;

    address public immutable ERC1155;
    uint256 public constant TIMELOCK_DURATION = 3 days;

    uint256 public shareIndex;
    uint256 public depositedETHAmount;
    uint256 public referralFeePercent = 5 * 1e16;
    uint256 public creatorFeePercent = 5 * 1e16;
    uint256 public migrationDeadline;

    IYieldAggregator public yieldAggregator;
    address public pendingAggregator;
    address public blankAggregator;

    event QueueMigrateYield(address indexed newAggregator, uint256 deadline);
    event MigrateYield(address indexed newAggregator, uint256 timestamp);
    event ClaimYield(uint256 amount, address indexed to);
    event SetCurve(uint8 indexed curveType);
    event SetFee(uint256 indexed feePercent, string feeType);
    event Mint(uint256 indexed id, address indexed creator, uint8 indexed curveType);
    event Buy(uint256 indexed id, address indexed buyer, uint32 quantity, uint256 totalPrice);
    event Sell(uint256 indexed id, address indexed seller, uint32 quantity, uint256 totalPrice);

    constructor(
        address _ERC1155,
        uint96 _basePrice,
        uint32 _inflectionPoint,
        uint128 _inflectionPrice,
        uint128 _linearPriceSlope
    ) {
        // Set ERC1155 address
        ERC1155 = _ERC1155;

        // Set default curve params
        curvesMap[0] = Curve({
            basePrice: _basePrice, // 5000000000000000;
            inflectionPoint: _inflectionPoint, // 1500;
            inflectionPrice: _inflectionPrice, // 102500000000000000;
            linearPriceSlope: _linearPriceSlope, // 0;
            exists: true
        });
    }

    fallback() external payable { }

    receive() external payable { }

    function getShare(uint256 shareId) public view returns (address creator, uint8 curveType) {
        require(shareId < shareIndex, "Invalid shareId");
        Share memory share = sharesMap[shareId];
        return (share.creator, share.curveType);
    }

    function getCurve(uint8 curveType) public view returns (uint96, uint32, uint128, uint128, bool) {
        require(curvesMap[curveType].exists, "Invalid curveType");
        Curve memory curve = curvesMap[curveType];
        uint96 basePrice = curve.basePrice;
        uint32 g = curve.inflectionPoint;
        uint128 h = curve.inflectionPrice;
        uint128 m = curve.linearPriceSlope;
        bool exists = curve.exists;
        return (basePrice, g, h, m, exists);
    }

    function getSubTotal(uint32 fromSupply, uint32 quantity, uint8 curveType) public view returns (uint256) {
        (uint96 basePrice, uint32 g, uint128 h, uint128 m,) = getCurve(curveType);
        return _subTotal(fromSupply, quantity, basePrice, g, h, m);
    }

    function setReferralFeePercent(uint256 _feePercent) external onlyOwner {
        referralFeePercent = _feePercent;
        emit SetFee(_feePercent, "referral");
    }

    function setCreatorFeePercent(uint256 _feePercent) external onlyOwner {
        creatorFeePercent = _feePercent;
        emit SetFee(_feePercent, "creator");
    }

    function setCurveType(
        uint8 _curveType,
        uint96 _basePrice,
        uint32 _inflectionPoint,
        uint128 _inflectionPrice,
        uint128 _linearPriceSlope
    ) external onlyOwner {
        require(!curvesMap[_curveType].exists, "Curve already initialized");

        Curve memory newCurve = Curve({
            basePrice: _basePrice,
            inflectionPoint: _inflectionPoint,
            inflectionPrice: _inflectionPrice,
            linearPriceSlope: _linearPriceSlope,
            exists: true
        });
        curvesMap[_curveType] = newCurve;

        emit SetCurve(_curveType);
    }

    /**
     * @notice Reset yieldAggregator, always fallback to blankAggregator.
     * Case 1: address(0) -> yieldAggregator, make the blankAggregator as default yieldAggregator.
     * Case 2: yieldAggregator -> blankAggregator, which cancels yield farming.
    */
    function resetYield(address _yieldAggregator) external onlyOwner {
        require(_yieldAggregator != address(0), "Invalid yieldAggregator");
        if (address(yieldAggregator) == address(0)) {
            blankAggregator = _yieldAggregator;
            _setYieldAggregator(_yieldAggregator);
        } else {
            _migrate(blankAggregator);
        }
    }

    /**
     * @notice Ask to migrate a new yield aggregator with timelock.
     * @param _yieldAggregator The address of the yield aggregator.
     */
    function queueMigrateYield(address _yieldAggregator) external onlyOwner {
        require(_yieldAggregator != address(0), "Invalid yieldAggregator");
        pendingAggregator = _yieldAggregator;
        migrationDeadline = block.timestamp + TIMELOCK_DURATION;
        emit QueueMigrateYield(_yieldAggregator, migrationDeadline);
    }
    
    /**
     * @notice Migrate a new yield aggregator after timelock.
     */
    function executeMigrateYield() external onlyOwner {
        require(pendingAggregator != address(0), "Invalid pendingAggregator");
        require(migrationDeadline != 0, "Invalid migrationDeadline");
        require(block.timestamp >= migrationDeadline, "Timelock not expired");  

        _migrate(pendingAggregator);

        delete pendingAggregator; // Reset pending aggregator
        delete migrationDeadline; // Reset migration deadline
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
     * @notice Mint a share and buy it in one transaction.
     * @param curveType The type of the curve.
     * @param quantity The quantity of shares.
     * @param referral The address of the referral fee recipient.
     */
    function mintAndBuyShare(uint8 curveType, uint32 quantity, address referral) public payable {
        mintShare(curveType);
        buyShare(shareIndex - 1, quantity, referral);
    }

    /**
     * @notice Mint a share with an auto-incremented ID.
     * @dev The share ID is identical to the ERC1155 ID.
     */
    function mintShare(uint8 curveType) public {
        require(curvesMap[curveType].exists, "Invalid curveType");

        Share memory newShare = Share({ creator: msg.sender, curveType: curveType });
        sharesMap[shareIndex] = newShare;

        emit Mint(shareIndex, msg.sender, curveType);

        shareIndex++;
    }

    /**
     * @param shareId The ID of the share.
     * @param quantity The quantity of shares.
     * @param referral The address of the referral fee recipient.
     */
    function buyShare(uint256 shareId, uint32 quantity, address referral) public payable {
        require(address(yieldAggregator) != address(0), "Invalid yieldAggregator");
        require(shareId < shareIndex, "Invalid shareId");

        (
            uint256 buyPriceAfterFee, 
            uint256 buyPrice, 
            uint256 referralFee, 
            uint256 creatorFee
        ) = getBuyPriceAfterFee(shareId, quantity, referral);
        require(msg.value >= buyPriceAfterFee, "Insufficient payment");

        // Mint shares to the buyer
        IShare(ERC1155).shareMint(msg.sender, shareId, quantity);
        emit Buy(shareId, msg.sender, quantity, buyPriceAfterFee);

        // Deposit the buy price (in ETH) to the yield aggregator (e.g., Aave)
        _safeTransferETH(address(yieldAggregator), buyPrice);
        yieldAggregator.yieldDeposit();
        depositedETHAmount += buyPrice;

        // Transfer referral and creator fees
        (address creator,) = getShare(shareId);
        _safeTransferETH(creator, creatorFee);
        _safeTransferETH(referral, referralFee);

        // If buyer paid more than necessary, refund the excess
        uint256 refundAmount = msg.value - buyPriceAfterFee;
        if (refundAmount > 0) {
            _safeTransferETH(msg.sender, refundAmount);
        }
    }

    /**
     * @param shareId The ID of the share.
     * @param quantity The quantity of shares.
     * @param minETHAmount The minimum amount of ETH will be used for slippage protection.
     * @param referral The address of the referral fee recipient.
     */
    function sellShare(
        uint256 shareId,
        uint32 quantity,
        uint256 minETHAmount,
        address referral
    ) public {
        require(shareId < shareIndex, "Invalid shareId");
        require(
            IShare(ERC1155).shareBalanceOf(msg.sender, shareId) >= quantity,
            "Insufficient shares"
        );

        (
            uint256 sellPriceAfterFee, 
            uint256 sellPrice, 
            uint256 referralFee, 
            uint256 creatorFee
        ) = getSellPriceAfterFee(shareId, quantity, referral);
        require(sellPriceAfterFee >= minETHAmount, "Insufficient minReceive");

        // Burn shares from the seller
        IShare(ERC1155).shareBurn(msg.sender, shareId, quantity);
        emit Sell(shareId, msg.sender, quantity, sellPriceAfterFee);

        // Withdraw the sell price (in ETH) from the yield aggregator (e.g. Aave)
        yieldAggregator.yieldWithdraw(sellPrice);
        depositedETHAmount -= sellPrice;

        // Transfer ETH to the seller
        _safeTransferETH(msg.sender, sellPriceAfterFee);

        // Transfer referral and creator fees
        (address creator,) = getShare(shareId);
        _safeTransferETH(creator, creatorFee);
        _safeTransferETH(referral, referralFee);
    }

    /**
     * @notice Calculates buy price and fees.
     * @return buyPriceAfterFee The amount user pay after fees.
     * @return buyPrice The initial price of the shares.
     * @return referralFee Fee by the referral. If = address(0), there is no referral fee.
     * @return creatorFee Fee by the share's creator.
     */
    function getBuyPriceAfterFee(
        uint256 shareId,
        uint32 quantity,
        address referral
    )
        public
        view
        returns (
            uint256 buyPriceAfterFee,
            uint256 buyPrice,
            uint256 referralFee,
            uint256 creatorFee
        )
    {
        (, uint8 curveType) = getShare(shareId);
        uint256 fromSupply = IShare(ERC1155).shareFromSupply(shareId);
        uint256 actualReferralFeePercent = referral != address(0) ? referralFeePercent : 0;

        buyPrice = getSubTotal(uint32(fromSupply), quantity, curveType);
        referralFee = (buyPrice * actualReferralFeePercent) / 1 ether;
        creatorFee = (buyPrice * creatorFeePercent) / 1 ether;
        buyPriceAfterFee = buyPrice + referralFee + creatorFee;
    }

    /**
     * @notice Calculates sell price and fees.
     * @return sellPriceAfterFee The amount user receives after fees.
     * @return sellPrice The initial price of the shares.
     * @return referralFee Fee by the referral. If = address(0), there is no referral fee.
     * @return creatorFee Fee by the share's creator.
     */
    function getSellPriceAfterFee(
        uint256 shareId,
        uint32 quantity,
        address referral
    )
        public
        view
        returns (
            uint256 sellPriceAfterFee,
            uint256 sellPrice,
            uint256 referralFee,
            uint256 creatorFee
        )
    {
        (, uint8 curveType) = getShare(shareId);
        uint256 fromSupply = IShare(ERC1155).shareFromSupply(shareId);
        uint256 actualReferralFeePercent = referral != address(0) ? referralFeePercent : 0;
        require(fromSupply >= quantity, "Exceeds supply");

        sellPrice = getSubTotal(uint32(fromSupply) - quantity, quantity, curveType);
        referralFee = (sellPrice * actualReferralFeePercent) / 1 ether;
        creatorFee = (sellPrice * creatorFeePercent) / 1 ether;
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
     * @notice migrate yield aggregator
     * @param _yieldAggregator The address of the yieldAggregator
     */
    function _migrate(address _yieldAggregator) internal {
        // Step 1: Withdraw all yieldToken into ETH.
        _withdrawAllYieldTokenToETH();

        // Step 2: Revoke the approval of the old yieldAggregator.
        address yieldToken = yieldAggregator.yieldToken();
        IERC20(yieldToken).safeApprove(address(yieldAggregator), 0);

        // Step 3: Set the new yieldAggregator.
        _setYieldAggregator(_yieldAggregator);

        // Step 4: Deposit all ETH into the new yieldAggregator as yieldToken.
        _depositAllETHToYieldToken();

        emit MigrateYield(address(_yieldAggregator), block.timestamp);
    }

    /**
     * @notice Withdraws all yieldToken into the SharesFactory as ETH.
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
    function _subTotal(
        uint32 fromSupply,
        uint32 quantity,
        uint96 basePrice,
        uint32 inflectionPoint,
        uint128 inflectionPrice,
        uint128 linearPriceSlope
    ) public pure returns (uint256 subTotal) {
        unchecked {
            subTotal = basePrice * quantity;
            subTotal += BondingCurveLib.linearSum(linearPriceSlope, fromSupply, quantity);
            subTotal += BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity);
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
            (bool success,) = to.call{ value: value }(new bytes(0));
            require(success, "ETH transfer failed");
        }
    }
}
