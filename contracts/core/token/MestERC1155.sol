// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { IMestShare } from "../../intf/IMestShare.sol";
import { Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MestERC1155 is ERC1155Supply, Ownable, IMestShare {
    address public _FACTORY_;
    string private _baseURI;

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

    function setURI(string memory newuri) public onlyOwner {
        _baseURI = newuri;
    }

    function shareMint(address to, uint256 id, uint256 amount) public onlyFactory {
        _mint(to, id, amount, "");
        emit Mint(to, id, amount);
    }

    function shareBurn(address from, uint256 id, uint256 amount) public onlyFactory {
        _burn(from, id, amount);
        emit Burn(from, id, amount);
    }

    function shareFromSupply(uint256 id) public view returns(uint256) {
        return totalSupply(id);
    }

    function shareBalanceOf(address user, uint256 id) public view returns(uint256) {
        return balanceOf(user, id);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURI, Strings.toString(tokenId)));
    }
}
