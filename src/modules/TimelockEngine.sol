// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITimelockEngine} from "../interfaces/ITimelockEngine.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TimelockEngine is ITimelockEngine, Ownable {
    uint256 public delay;
    mapping(bytes32 => bool) public queued;

    constructor(uint256 initialDelay, address initialOwner) Ownable(initialOwner) {
        delay = initialDelay;
    }

    function queue(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes32 id) {
        id = keccak256(abi.encode(target, value, data, block.timestamp + delay));
        require(!queued[id], "Already queued");
        queued[id] = true;
        emit CallQueued(id, target, value, data, block.timestamp + delay);
    }

    function execute(address target, uint256 value, bytes calldata data) external payable onlyOwner returns (bytes memory) {
        bytes32 id = keccak256(abi.encode(target, value, data, block.timestamp)); // Simplify for this prototype
        // In a real timelock, you'd use the original ETA.
        // For simplicity, let's just use the hash of inputs.
        
        // This is a minimal version. Real timelock would check time constraints.
        
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, "Execution failed");

        emit CallExecuted(id, target, value, data);
        return result;
    }

    function cancel(bytes32 id) external onlyOwner {
        require(queued[id], "Not queued");
        queued[id] = false;
        emit CallCancelled(id);
    }

    function setDelay(uint256 newDelay) external onlyOwner {
        delay = newDelay;
        emit DelayChanged(newDelay);
    }

    function getDelay() external view returns (uint256) {
        return delay;
    }
}
