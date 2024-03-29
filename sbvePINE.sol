// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


contract VEPine is OwnableUpgradeable, ERC20Upgradeable {
  address public pine;
  uint256 public maxStakes;

  struct StakeInfo {
    uint256 totalAmount;
    uint256[] amounts;
    uint256[] stakedAt;
    uint256 lastWithdrawalAt;
  }

  mapping(address => StakeInfo) public staking;
  mapping(address => uint256) public burnt;
  address[] public users;
  mapping(address => bool) usersEnabled;

  event Staked(address staker, uint256 amount, uint256 timestamp);
  event Claimed(address claimer, uint256 amount, uint256 timestamp);
  event Withdrew(address user, uint256 amount, uint256 timestamp);

  function init(
    address _pine, 
    string memory _name, 
    string memory _symbol,
    uint256 _maxStakes
  ) external initializer {
    __Ownable_init();
    __ERC20_init(_name, _symbol);
    pine = _pine;
    maxStakes = _maxStakes;
  }

  // This token cannot be transferred
  function _beforeTokenTransfer(address from, address to, uint256 amount)
      internal
      override
  {
    require(_msgSender() == address(0), "This token is untransferrable");
    super._beforeTokenTransfer(from, to, amount);
  }

  function setMaxStakes(uint256 _maxStakes) external {
    maxStakes = _maxStakes;
  }

  // RISK-07: This may fail. Fallback is to just add up everything via snapshot script
  function totalVeSb() public view returns (uint256) {
    uint256 _totalSupply = 0;
    for (uint i = 0; i < users.length; i ++) {
      _totalSupply += userVeSb(users[i]);
    }

    return _totalSupply;
  }

  function userVeSb(address _user) public view returns (uint256 pendingReward) {
    StakeInfo memory stakeInfo = staking[_user];
    uint256 accrualAmount = 0;
    require(stakeInfo.totalAmount != 0, "insufficient staked amount");

    for (uint i = stakeInfo.amounts.length - 1; i >= 0; i--) {
      if (stakeInfo.stakedAt[i] > stakeInfo.lastWithdrawalAt) {
        accrualAmount += stakeInfo.amounts[i] * 11**((block.timestamp - stakeInfo.stakedAt[i]) / (3*360*24*60*60)) - 1;
      } else {
        break;
      }
    }

    pendingReward = stakeInfo.totalAmount - accrualAmount + burnt[_user];
  }

  function burn(uint256 _amount) external {
      require(ERC20Upgradeable(pine).transferFrom(_msgSender(), pine, _amount));
    burnt[_msgSender()] += _amount;
  }

  function stake(uint256 _amount) external {
    require(_amount > 0, "invalid amount");
    require(staking[_msgSender()].amounts.length < maxStakes, "maxStakes exceeded");
    require(ERC20Upgradeable(pine).balanceOf(_msgSender()) >= _amount, "insufficient amount.");
    require(ERC20Upgradeable(pine).allowance(_msgSender(), address(this)) >= _amount, "insufficient allowance amount.");

    require(ERC20Upgradeable(pine).transferFrom(_msgSender(), address(this), _amount) == true, "transfer failed.");

    if (staking[_msgSender()].totalAmount == 0) {
      users.push(_msgSender());
    }

    staking[_msgSender()].totalAmount += _amount;
    staking[_msgSender()].amounts.push(_amount);
    staking[_msgSender()].stakedAt.push(block.timestamp);
    usersEnabled[_msgSender()] = true;

    emit Staked(_msgSender(), _amount, block.timestamp);
  }

  function getPendingRewards() public view returns (uint256 pendingReward) {
    return balanceOf(_msgSender());
  }

  function withdraw(uint256 amount) external {
    require(staking[_msgSender()].totalAmount >= amount, "insufficient staked amount");
    uint i = staking[_msgSender()].amounts.length - 1;

    while (amount > staking[_msgSender()].amounts[i]) {
      amount -= staking[_msgSender()].amounts[i --];
      staking[_msgSender()].amounts.pop();
      staking[_msgSender()].stakedAt.pop();
    }

    if (amount == staking[_msgSender()].amounts[i]) {
      staking[_msgSender()].amounts.pop();
      staking[_msgSender()].stakedAt.pop();
    } else {
      staking[_msgSender()].amounts[i] -= amount;
    }

    require(ERC20Upgradeable(pine).transfer(_msgSender(), amount) == true, "withdraw failed.");
    
    staking[_msgSender()].totalAmount -= amount;
    staking[_msgSender()].lastWithdrawalAt = block.timestamp;

    if (staking[_msgSender()].totalAmount <= 0) usersEnabled[_msgSender()] = false;

    emit Withdrew(_msgSender(), amount, block.timestamp);
  }
}
