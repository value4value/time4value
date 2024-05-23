pragma solidity ^0.8.25;

import { StdUtils } from "forge-std/StdUtils.sol";
import { Vm } from "forge-std/Vm.sol";
import { SharesFactoryV1 } from "contracts/core/SharesFactoryV1.sol";
import { SharesERC1155 } from "contracts/core/SharesERC1155.sol";

contract BoundedIntegrationContextHandler is StdUtils {
    mapping(bytes32 => uint256) public numCalls;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address public factoryOwner;
    SharesERC1155 public sharesNFT;
    SharesFactoryV1 public sharesFactory;

    address public constant FACTORY_OWNER = address(1);

    address public constant TRADER = address(5);

    // @dev internal helper state for bounded range calculation
    mapping(uint8 => bool) public usedCurveType;

    constructor(address _factoryOwner, SharesFactoryV1 _sharesFactory, SharesERC1155 _sharesNFT) {
        factoryOwner = _factoryOwner;
        sharesFactory = SharesFactoryV1(_sharesFactory);
        sharesNFT = SharesERC1155(_sharesNFT);
    }

    function setCurveType(
        uint8 _curveType,
        uint96 _basePrice,
        uint32 _inflectionPoint,
        uint128 _inflectionPrice,
        uint128 _linearPriceSlope
    ) public {
        numCalls["boundedIntContext.setCurveType"]++;

        vm.assume(!usedCurveType[_curveType]);
        bound(_curveType, 0, 100);
        bound(_basePrice, 0.005 ether, 0.1 ether);
        bound(_inflectionPoint, 1000, 2000);
        bound(_inflectionPrice, 0.01 ether, 0.5 ether);
        bound(_linearPriceSlope, 0, 0);

        usedCurveType[_curveType] = true;
        vm.prank(factoryOwner);
        sharesFactory.setCurveType(_curveType, _basePrice, _inflectionPoint, _inflectionPrice, _linearPriceSlope);
    }

    function buy(uint32 quantity) public {
        numCalls["boundedIntContext.buy"]++;

        bound(quantity, 1, 1000);

        uint256 shareId = 0;

        vm.prank(factoryOwner);
        sharesFactory.mintShare(0);

        vm.prank(TRADER);

        (uint256 buyPriceAfterFee,,,) = sharesFactory.getBuyPriceAfterFee(shareId, quantity, FACTORY_OWNER);
        vm.prank(TRADER);
        sharesFactory.buyShare{ value: buyPriceAfterFee }(shareId, quantity, FACTORY_OWNER);
    }

    function test() public { }
}
