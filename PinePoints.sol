// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

enum Category {
    AIRDROP,
    BORROW_HOURLY_INCENTIVE,
    LENDING_HOURLY_INCENTIVE,
    PNPL_ONE_TIME
}

enum Box {
    GOLD,
    SILVER,
    BRONZE
}

interface IBox {
    function boxValue(Box boxType) external returns (uint256);
    function mintBox(address to, Box boxType) external;
}

struct Batch{
    address to;
    uint256 amount;
    Category category;
    uint16[] year_month_day_hour;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract PinePoints is Initializable, ERC20Upgradeable, PausableUpgradeable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    address public signer;
    IBox public box;
    mapping(bytes32 => bool) claimed;
    event Claimed(address indexed to, Category indexed category, uint16[] year_month_day_hour, uint256 amount);

    function initialize(address _signer, IBox _box) initializer public {
        __ERC20_init("Pine Points", "PINEPOINTS");
        __Pausable_init();
        __Ownable_init();
        require(signer != address(0));
        signer = _signer;
        box = _box;
    }

    function lazyMint(address to, uint256 amount, Category category, uint16[] calldata year_month_day_hour, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 pointHash = keccak256(abi.encode(to, category, year_month_day_hour));
        require(!claimed[pointHash], "Batch already claimed");
        require(signer == ecrecover(pointHash, v, r, s), "Signature wrong");
        claimed[pointHash] = true;
        _mint(to, amount);
        emit Claimed(to, category, year_month_day_hour, amount);
    }

    function batchLazyMint(Batch[] calldata batches) external {
        // RISK-05: acknowledged. This will be controlled by frontend
        for (uint i; i< batches.length;) {
            try this.lazyMint(batches[i].to, batches[i].amount, batches[i].category, batches[i].year_month_day_hour, batches[i].v, batches[i].r, batches[i].s) {} catch {

            }
            unchecked {
                i++;
            }
        }
    }

    function mintBox(Box boxType) external {
        _transfer(msg.sender, address(box), box.boxValue(boxType));
        box.mintBox(msg.sender, boxType);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}
