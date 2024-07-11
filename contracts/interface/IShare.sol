// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

interface IShare {
    function setTokenURI(uint256 tokenId, string memory tokenURI) external;

    function shareMint(address to, uint256 id, uint256 amount) external;

    function shareBurn(address from, uint256 id, uint256 amount) external;

    function shareFromSupply(uint256 id) external view returns (uint256);

    function shareBalanceOf(address user, uint256 id) external view returns (uint256);
}
