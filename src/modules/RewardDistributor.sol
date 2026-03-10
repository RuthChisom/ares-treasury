// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRewardDistributor} from "../interfaces/IRewardDistributor.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RewardDistributor is IRewardDistributor, Ownable {
    bytes32 public root;
    mapping(address => mapping(uint256 => bool)) private _claimed;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setRoot(bytes32 newRoot) external onlyOwner {
        emit RootUpdated(root, newRoot);
        root = newRoot;
    }

    function claim(uint256 amount, bytes32[] calldata proof) external {
        require(!_claimed[msg.sender][amount], "Already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");

        _claimed[msg.sender][amount] = true;
        emit Claimed(msg.sender, amount, root);

        // Logic to transfer tokens from treasury to claimer would go here or be triggered from treasury.
    }

    function isClaimed(address account, uint256 amount) external view returns (bool) {
        return _claimed[account][amount];
    }
}
