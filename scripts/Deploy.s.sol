// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import "forge-std/Script.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";
import { AaveYieldAggregator } from "contracts/core/aggregator/AaveYieldAggregator.sol";
import { BlankYieldAggregator } from "contracts/core/aggregator/BlankYieldAggregator.sol";
import { IYieldAggregator } from "contracts/interface/IYieldAggregator.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAavePool } from "contracts/interface/IAave.sol";

contract DeployScript is Script {
    SharesFactoryV1 public sharesFactory;
    SharesERC1155 public sharesNFT;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;

    // Optimism Sepolia
    address public OWNER = 0xdA1d0C7f174effBA98Ea1E31424418DC9aeaEa22;
    address public WETH = 0x4200000000000000000000000000000000000006;
    address public AAVE_POOL = 0xb50201558B00496A145fE76f7424749556E326D8;
    address public AAVE_WETH_GATEWAY = 0x589750BA8aF186cE5B55391B0b7148cAD43a1619;

    // Optimism Mainnet
    // address public OWNER = 0xdA1d0C7f174effBA98Ea1E31424418DC9aeaEa22;
    // address public WETH = 0x4200000000000000000000000000000000000006;
    // address public AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    // address public AAVE_WETH_GATEWAY = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;

    IERC20 public aWETH = IERC20(IAavePool(AAVE_POOL).getReserveData(WETH).aTokenAddress);

    string public constant BASE_URI = "https://v4v.com/shares/uri/";
    uint256 public constant BASE_PRICE = 5000000000000000; // 0.005 ETH as base price
    uint256 public constant INFLECTION_POINT = 1500;
    uint256 public constant INFLECTION_PRICE = 102500000000000000;
    uint256 public constant LINEAR_PRICE_SLOPE = 0;

    function run() public virtual {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        sharesNFT = new SharesERC1155(BASE_URI);

        sharesFactory = new SharesFactoryV1(
            address(sharesNFT), 
            BASE_PRICE, 
            INFLECTION_POINT, 
            INFLECTION_PRICE, 
            LINEAR_PRICE_SLOPE
        );

        aaveYieldAggregator = new AaveYieldAggregator(address(sharesFactory), WETH, AAVE_POOL, AAVE_WETH_GATEWAY);
        blankYieldAggregator = new BlankYieldAggregator(address(sharesFactory), WETH);

        sharesNFT.setFactory(address(sharesFactory));
        sharesFactory.migrate(address(aaveYieldAggregator));

        sharesNFT.transferOwnership(OWNER);
        sharesFactory.transferOwnership(OWNER);
        aaveYieldAggregator.transferOwnership(OWNER);

        vm.stopBroadcast();
    }
}
