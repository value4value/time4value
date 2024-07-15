// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import { Script } from "forge-std/Script.sol";

contract BaseScript is Script {

    // multi-sig wallet as owner.
    address public OWNER = 0xb2dDDBdD1EB4EcF95BA63f271e40073860929a46;

    uint256 public constant OPTIMISM_MAINNET = 10;
    uint256 public constant OPTIMISM_SEPOLIA = 11155420;
    uint256 public constant CYBER_MAINNET = 7560;
    uint256 public constant CYBER_TESTNET = 111557560;

    mapping(uint chainid => address shares_factory) public SHARES_FACTORY;
    mapping(uint chainid => address weth) public WETH;
    mapping(uint chainid => address aave_pool) public AAVE_POOL;
    mapping(uint chainid => address aave_weth_gateway) public AAVE_WETH_GATEWAY;

    constructor() {
        // After the factory contract has been deployed, 
        // set the factory address here so that the yieldAggregator can be deployed.

        // Optimism Sepolia
        SHARES_FACTORY[OPTIMISM_SEPOLIA] = 0x1637A51717db3F62f836944FdE09BFA4C673b2D9;
        WETH[OPTIMISM_SEPOLIA] = 0x4200000000000000000000000000000000000006;
        AAVE_POOL[OPTIMISM_SEPOLIA] = 0xb50201558B00496A145fE76f7424749556E326D8;
        AAVE_WETH_GATEWAY[OPTIMISM_SEPOLIA] = 0x589750BA8aF186cE5B55391B0b7148cAD43a1619;

        // Optimism Mainnet
        SHARES_FACTORY[OPTIMISM_MAINNET] = 0xc2BDb7510CDD65a1bA7aD9b490033563b24f141F;
        WETH[OPTIMISM_MAINNET] = 0x4200000000000000000000000000000000000006;
        AAVE_POOL[OPTIMISM_MAINNET] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
        AAVE_WETH_GATEWAY[OPTIMISM_MAINNET] = 0xe9E52021f4e11DEAD8661812A0A6c8627abA2a54;

        // Cyber Testnet
        SHARES_FACTORY[CYBER_TESTNET] = address(0);
        WETH[CYBER_TESTNET] = 0x4200000000000000000000000000000000000006;
        AAVE_POOL[CYBER_TESTNET] = address(0);
        AAVE_WETH_GATEWAY[CYBER_TESTNET] = address(0);

        // Cyber Mainnet
        SHARES_FACTORY[CYBER_MAINNET] = address(0);
        WETH[CYBER_MAINNET] = 0x4200000000000000000000000000000000000006;
        AAVE_POOL[CYBER_MAINNET] = address(0);
        AAVE_WETH_GATEWAY[CYBER_MAINNET] = address(0);

    }

    modifier broadcast() {
        uint256 broadcaster = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }
}