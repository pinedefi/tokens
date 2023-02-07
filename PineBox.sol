// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Box, IBox } from "./PinePoints.sol";

contract PineMystery is Initializable, ERC1155Upgradeable, OwnableUpgradeable, IBox {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    IERC20 pointsContract;

    mapping (Box => uint256) public boxValue;

    function setBoxValue(Box boxType, uint256 value) external onlyOwner {
        boxValue[boxType] = value;
    }

    function initialize(IERC20 _pointsContract) initializer public {
        __ERC1155_init("");
        __Ownable_init();
        pointsContract = _pointsContract;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    // to be called by points contract
    function mintBox(address to, Box boxType) external override {
        require(msg.sender == address(pointsContract), "Wrong operator");
        require(pointsContract.balanceOf(address(this)) >= boxValue[boxType], "Not enough points");
        uint256 amount = pointsContract.balanceOf(address(this)) / boxValue[boxType];
        _mint(to, uint8(boxType), amount, "");
    }
}
