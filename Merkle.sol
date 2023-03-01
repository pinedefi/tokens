// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

library MerkleProof {
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf,
        uint index
    ) public pure returns (bool) {
        bytes32 hash = leaf;

        for (uint i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (index % 2 == 0) {
                hash = keccak256(abi.encodePacked(hash, proofElement));
            } else {
                hash = keccak256(abi.encodePacked(proofElement, hash));
            }

            index = index / 2;
        }

        return hash == root;
    }
}

contract MerkleClaimer is OwnableUpgradeable, PausableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // STORAGE
    ERC20Upgradeable token;
    mapping (bytes32 => bool) public activatedMerkleRoots;
    mapping (bytes32 => uint256) public rootActivationTime;
    mapping (bytes32 => bool) public root_leaf_index_hash_claimed;
    uint256[] public array;
    // NO STORAGE AFTER THIS POINT

    function initialize(ERC20Upgradeable _token) initializer public {
        __Ownable_init();
        token = _token;
    }

    function getAllArray() public returns (uint256[] memory) {
        return array;
    }

    modifier rootActive(bytes32 root) {
        require(activatedMerkleRoots[root], "Reward not active");
        require(block.timestamp >= rootActivationTime[root], "Claiming is not open yet. Please try again");
        _;
    }

    function activateRoot(bytes32 root, uint256 timestamp) onlyOwner external {
        activatedMerkleRoots[root] = true;
        rootActivationTime[root] = timestamp;
    }

    function claimReward(bytes32 root, bytes32[] memory proof, uint256 amount, uint256 index) rootActive(root) external {
        bytes32 leaf = keccak256(abi.encode(msg.sender, amount));
        require(!root_leaf_index_hash_claimed[keccak256(abi.encode(root, leaf, index))], "Reward already claimed");
        require(MerkleProof.verify(proof, root, leaf, index), "Some verification went wrong. Please contact the team.");
        root_leaf_index_hash_claimed[keccak256(abi.encode(root, leaf, index))] = true;
        token.transfer(msg.sender, amount);
    }

    modifier batchRootActive(bytes32[] memory root) {
        for (uint i = 0; i < root.length; i ++) {
            require(activatedMerkleRoots[root[i]], "One of the reward not active");
            require(block.timestamp >= rootActivationTime[root[i]], "One of the claiming is not open yet. Please try again");
        }
        _;
    }

    function batchClaimReward(bytes32[] memory root, bytes32[][] memory proofs, uint256[] memory amount, uint256[] memory index) batchRootActive(root) external {
        require(root.length == proofs.length, "Invalid params");
        require(root.length == amount.length, "Invalid params");
        require(root.length == index.length, "Invalid params");

        uint256 totalAmount = 0;

        for (uint i = 0; i < root.length; i ++) {
            bytes32 leaf = keccak256(abi.encode(msg.sender, amount[i]));
            require(!root_leaf_index_hash_claimed[keccak256(abi.encode(root[i], leaf, index[i]))], "One of the reward already claimed");
            require(MerkleProof.verify(proofs[i], root[i], leaf, index[i]), "Some verification went wrong. Please contact the team.");
            root_leaf_index_hash_claimed[keccak256(abi.encode(root[i], leaf, index[i]))] = true;
            totalAmount += amount[i];
        }

        token.transfer(msg.sender, totalAmount);
    }
}