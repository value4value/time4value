// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { BaseTest } from "../BaseTest.t.sol";

contract ERC1155Tests is BaseTest {
    address private addrFactory = makeAddr("factory");
    address private addrUser = makeAddr("user");

    function setUp() public {
        createFactory();
    }

    function test_setURI() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesNFT.setURI(BASE_URI);

        vm.prank(owner);
        sharesNFT.setURI(BASE_URI);

        string memory shareUri = sharesNFT.uri(0);
        assertEq(shareUri, "https://vv.meme/shares/uri/0");
    }

    function test_setFactory() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sharesNFT.setFactory(addrFactory);

        vm.prank(owner);
        sharesNFT.setFactory(addrFactory);

        // check if factory is set by mint
        vm.prank(addrFactory);
        sharesNFT.shareMint(addrUser, 0, 10);
        uint256 userBal = sharesNFT.balanceOf(addrUser, 0);
        assertEq(userBal, 10);
    }

    function test_setTokenURI() public {
        vm.expectRevert(bytes("Caller is not the factory"));
        sharesNFT.setTokenURI(0, "https://vv.com/0");

        vm.prank(address(sharesFactory));
        sharesNFT.setTokenURI(0, "https://vv.com/0");

        string memory tokenURI = sharesNFT.tokenURIs(0);
        assertEq(tokenURI, "https://vv.com/0");
    }

    function test_shareMint() public {
        vm.prank(address(sharesFactory));
        sharesNFT.shareMint(addrUser, 0, 10);

        uint256 userBal = sharesNFT.balanceOf(addrUser, 0);
        assertEq(userBal, 10);
    }

    function test_shareBurn() public {
        vm.startPrank(address(sharesFactory));
        sharesNFT.shareMint(addrUser, 0, 10);
        sharesNFT.shareBurn(addrUser, 0, 10);
        vm.stopPrank();

        uint256 userBal = sharesNFT.balanceOf(addrUser, 0);
        assertEq(userBal, 0);
    }

    function testOnlyFactory() public {
        vm.prank(address(addrUser));
        vm.expectRevert(bytes("Caller is not the factory"));
        sharesNFT.shareMint(addrUser, 0, 10);

        vm.prank(address(addrUser));
        vm.expectRevert(bytes("Caller is not the factory"));
        sharesNFT.shareBurn(addrUser, 0, 10);
    }
}
