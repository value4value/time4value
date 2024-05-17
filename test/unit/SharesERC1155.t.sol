// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

//import { BaseTest } from "../BaseTest.t.sol";
import "../BaseTest.t.sol";

contract ERC1155Tests is BaseTest {
    address private mockFactory = address(1);
    address private mockUser = address(2);

    function setUp() public {
        createFactory();
    }

    function test_setURI() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesNFT.setURI(BASE_URI);

        vm.prank(owner);
        sharesNFT.setURI(BASE_URI);

        string memory shareUri = sharesNFT.uri(0);
        assertEq(shareUri, "https://v4v.com/shares/uri/0");
    }

    function test_setFactory() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesNFT.setFactory(mockFactory);

        vm.prank(owner);
        sharesNFT.setFactory(mockFactory);

        // check if factory is set by mint
        vm.prank(mockFactory);
        sharesNFT.shareMint(mockUser, 0, 10);
        uint256 mockUserBal = sharesNFT.balanceOf(mockUser, 0);
        assertEq(mockUserBal, 10);
    }

    function test_shareMint() public {
        vm.prank(address(sharesFactory));
        sharesNFT.shareMint(mockUser, 0, 10);

        uint256 mockUserBal = sharesNFT.balanceOf(mockUser, 0);
        assertEq(mockUserBal, 10);
    }

    function test_shareBurn() public {
        vm.startPrank(address(sharesFactory));
        sharesNFT.shareMint(mockUser, 0, 10);
        sharesNFT.shareBurn(mockUser, 0, 10);
        vm.stopPrank();

        uint256 mockUserBal = sharesNFT.balanceOf(mockUser, 0);
        assertEq(mockUserBal, 0);
    }

    function testOnlyFactory() public {
        vm.prank(address(mockUser));
        vm.expectRevert(bytes("Caller is not the factory"));
        sharesNFT.shareMint(mockUser, 0, 10);

        vm.prank(address(mockUser));
        vm.expectRevert(bytes("Caller is not the factory"));
        sharesNFT.shareBurn(mockUser, 0, 10);
    }
}
