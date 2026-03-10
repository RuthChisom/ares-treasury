// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasury {
    event Executed(address indexed target, uint256 value, bytes data);
    event Deposited(address indexed sender, uint256 amount);

    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory);
    function getBalance() external view returns (uint256);
}
