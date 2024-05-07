// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "contracts/core/MestSharesFactoryV1.sol";
import "contracts/core/YieldAggregator/AaveYieldAggregator.sol";
import { MestERC1155 } from "contracts/core/MestERC1155.sol";
import { BlankYieldAggregator } from "contracts/core/YieldAggregator/BlankYieldAggregator.sol";
import { IYieldAggregator } from "contracts/intf/IYieldAggregator.sol";

contract DeployScript is Script {
    MestSharesFactoryV1 public sharesFactory;
    MestERC1155 public sharesNFT;

    AaveYieldAggregator public aaveYieldAggregator;
    BlankYieldAggregator public blankYieldAggregator;

    // Optimism Sepolia
    address public owner = 0xdA1d0C7f174effBA98Ea1E31424418DC9aeaEa22;
    address public weth = 0x4200000000000000000000000000000000000006;
    address public aavePool = 0xb50201558B00496A145fE76f7424749556E326D8;
    address public aaveGateway = 0x589750BA8aF186cE5B55391B0b7148cAD43a1619;

    // Optimism Mainnet
    // address public owner = 0xdA1d0C7f174effBA98Ea1E31424418DC9aeaEa22;
    // address public weth = 0x4200000000000000000000000000000000000006;
    // address public aavePool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    // address public aaveGateway = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;

    IAToken public aWETH = IAToken(IAavePool(aavePool).getReserveData(weth).aTokenAddress);

    string public baseURI = "https://mest.io/shares/";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        sharesNFT = new MestERC1155(baseURI);

        sharesFactory = new MestSharesFactoryV1(
            address(sharesNFT), 
            5000000000000000, // basePrice, 
            1500, // linearPriceSlope, 
            102500000000000000, // inflectionPoint, 
            0 // inflectionPrice
        );

        aaveYieldAggregator = new AaveYieldAggregator(
            address(sharesFactory), 
            weth, 
            aavePool, 
            aaveGateway
        );

        blankYieldAggregator = new BlankYieldAggregator(
            address(sharesFactory), 
            weth
        );

        sharesNFT.setFactory(address(sharesFactory));
        sharesNFT.transferOwnership(owner);
        sharesFactory.transferOwnership(owner);
        aaveYieldAggregator.transferOwnership(owner);

        vm.stopBroadcast();
    }
}