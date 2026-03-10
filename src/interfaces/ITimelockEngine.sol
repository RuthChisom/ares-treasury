// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITimelockEngine {
    event CallQueued(bytes32 indexed id, address indexed target, uint256 value, bytes data, uint256 eta);
    event CallExecuted(bytes32 indexed id, address indexed target, uint256 value, bytes data);
    event CallCancelled(bytes32 indexed id);
    event DelayChanged(uint256 newDelay);

    function queue(address target, uint256 value, bytes calldata data) external returns (bytes32);
    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory);
    function cancel(bytes32 id) external;
    function getDelay() external view returns (uint256);
}
