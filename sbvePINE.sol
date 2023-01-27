// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract VEPine is Ownable, ERC20 {
  using SafeMath for uint256;
  address public pine;

  struct StakeInfo {
    uint256 totalAmount;
    uint256[] amounts;
    uint256[] stakedAt;
    uint256 lastWithdrawalAt;
  }

  mapping(address => StakeInfo) public staking;
  mapping(address => uint256) public burnt;
  address[] public users;

  event Staked(address staker, uint256 amount, uint256 timestamp);
  event Claimed(address claimer, uint256 amount, uint256 timestamp);
  event Withdrew(address user, uint256 amount, uint256 timestamp);

  constructor(
    address _pine, 
    string memory _name, 
    string memory _symbol
  ) ERC20(_name, _symbol) {
    pine = _pine;
  }

  function totalSupply() public override view returns (uint256) {
    uint256 _totalSupply = 0;
    for (uint i = 0; i < users.length; i ++) {
      _totalSupply += balanceOf(users[i]);
    }

    return _totalSupply;
  }

  function balanceOf(address _user) public override view returns (uint256 pendingReward) {
    StakeInfo memory stakeInfo = staking[_user];
    uint256 accrualAmount = 0;
    require(stakeInfo.totalAmount != 0, "insufficient staked amount");

    for (uint i = stakeInfo.amounts.length - 1; i >= 0; i--) {
      if (stakeInfo.stakedAt[i] > stakeInfo.lastWithdrawalAt) {
        accrualAmount += 11**((block.timestamp - stakeInfo.stakedAt[i]) / (3*360*24*60*60)) - 1;
      } else {
        break;
      }
    }

    pendingReward = stakeInfo.totalAmount - accrualAmount + burnt[_user];
  }

  function burn(uint256 _amount) external {
      require(ERC20(pine).transferFrom(_msgSender(), pine, _amount));
    burnt[_msgSender()] += _amount;
  }

  function stake(uint256 _amount) external {
    require(_amount > 0, "invalid amount");
    require(ERC20(pine).balanceOf(_msgSender()) >= _amount, "insufficient amount.");
    require(ERC20(pine).allowance(_msgSender(), address(this)) >= _amount, "insufficient allowance amount.");

    require(ERC20(pine).transferFrom(_msgSender(), address(this), _amount) == true, "transfer failed.");

    if (staking[_msgSender()].totalAmount == 0) {
      users.push(_msgSender());
    }

    staking[_msgSender()].totalAmount += _amount;
    staking[_msgSender()].amounts.push(_amount);
    staking[_msgSender()].stakedAt.push(block.timestamp);

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

    require(ERC20(pine).transfer(_msgSender(), amount) == true, "withdraw failed.");
    
    staking[_msgSender()].totalAmount -= amount;
    staking[_msgSender()].lastWithdrawalAt = block.timestamp;

    emit Withdrew(_msgSender(), amount, block.timestamp);
  }
}
