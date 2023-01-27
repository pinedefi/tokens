ERC20

 Copy to Clipboard
 Open in Remix
 Download
settings
Name
Pine
Symbol
PINE
Premint
200000000
features
Mintable
Burnable
Pausable
Permit
Votes
Flash Minting
Snapshots
access control

Ownable
Roles
upgradeability

Transparent
UUPS
info
Security Contact
security@example.com
License
MIT
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Pine is Initializable, ERC20Upgradeable, PausableUpgradeable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC20_init("Pine", "PINE");
        __Pausable_init();
        __Ownable_init();

        _mint(msg.sender, 200000000 * 10 ** decimals());
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
