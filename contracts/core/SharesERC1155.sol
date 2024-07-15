// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IShare } from "../interface/IShare.sol";

contract SharesERC1155 is ERC1155Supply, Ownable, IShare {
    address public _FACTORY_;
    string private _baseURI;
    mapping(uint256 => string) public tokenURIs;

    event Mint(address indexed user, uint256 indexed id, uint256 amount);
    event Burn(address indexed user, uint256 indexed id, uint256 amount);

    modifier onlyFactory() {
        require(msg.sender == _FACTORY_, "Caller is not the factory");
        _;
    }

    constructor(string memory baseURI_) ERC1155(baseURI_) {
        _baseURI = baseURI_;
    }

    function setFactory(address newFactory) public onlyOwner {
        _FACTORY_ = newFactory;
    }

    function setURI(string memory newURI) public onlyOwner {
        _baseURI = newURI;
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) public onlyFactory {
        tokenURIs[tokenId] = tokenURI;
    }

    function shareMint(address to, uint256 id, uint256 amount) public onlyFactory {
        _mint(to, id, amount, "");
        emit Mint(to, id, amount);
    }

    function shareBurn(address from, uint256 id, uint256 amount) public onlyFactory {
        _burn(from, id, amount);
        emit Burn(from, id, amount);
    }

    function shareFromSupply(uint256 id) public view returns (uint256) {
        return totalSupply(id);
    }

    function shareBalanceOf(address user, uint256 id) public view returns (uint256) {
        return balanceOf(user, id);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURI, Strings.toString(tokenId)));
    }
}
