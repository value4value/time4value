/*

    Copyright 2024 MEST.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {MestERC1155} from "contracts/core/token/MestERC1155.sol";
import  "contracts/core/MestSharesFactoryV1.sol";

contract TestContext is Test {
    MestSharesFactoryV1 public mestFactory;
    MestERC1155 public erc1155TokenTemp;

    address public receiver = address(999);
    address public owner = address(1);
    address public weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    


    function createMestFactory() public {
        erc1155TokenTemp = new MestERC1155("http://mest.io/share/");
        mestFactory = new MestSharesFactoryV1(receiver, address(erc1155TokenTemp), weth);
        mestFactory.transferOwnership(owner);
        erc1155TokenTemp.setFactory(address(mestFactory));
        erc1155TokenTemp.transferOwnership(owner);

        vm.prank(owner);
        mestFactory.setAaveInfo(0x794a61358D6845594F94dc1DB02A252b5b4814aD, 0xecD4bd3121F9FD604ffaC631bF6d41ec12f1fafb);
    }

    function testSuccess() public {}
}