// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "../TestContext.t.sol";

contract MestERC1155Tests is TestContext {
    address mockFactory = address(999);
    address mockUser = address(8);

    function setUp() public {
        createMestFactory();
    }

    function testSetURI() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        erc1155TokenTemp.setURI("https://test.io/");
        vm.prank(owner);
        erc1155TokenTemp.setURI("https://test.io/");

        string memory shareUri = erc1155TokenTemp.uri(0);
        assertEq(shareUri, "https://test.io/0");
    }

    function testSetFactory() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        erc1155TokenTemp.setFactory(mockFactory);
        vm.prank(owner);
        erc1155TokenTemp.setFactory(mockFactory);

        vm.prank(mockFactory);
        erc1155TokenTemp.shareMint(mockUser, 0, 10);
        uint256 mockUserBal = erc1155TokenTemp.balanceOf(mockUser, 0);
        assertEq(mockUserBal, 10);
    }

}
