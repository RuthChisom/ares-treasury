// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRewardDistributor {
    event Claimed(address indexed account, uint256 amount, bytes32 indexed root);
    event RootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    function claim(uint256 amount, bytes32[] calldata proof) external;
    function setRoot(bytes32 newRoot) external;
    function isClaimed(address account, uint256 amount) external view returns (bool);
}
