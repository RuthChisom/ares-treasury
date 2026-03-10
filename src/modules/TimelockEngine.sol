// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITimelockEngine} from "../interfaces/ITimelockEngine.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TimelockEngine
 * @dev Implements queue-based delayed execution for treasury proposals.
 */
contract TimelockEngine is ITimelockEngine, Ownable, ReentrancyGuard {
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    uint256 public delay;
    mapping(bytes32 => bool) public queuedTransactions;

    error DelayTooShort(uint256 provided, uint256 minimum);
    error NotQueued(bytes32 id);
    error TimestampNotPassed(uint256 eta);
    error TransactionExpired(uint256 expiry);
    error ExecutionFailed();

    constructor(uint256 initialDelay, address initialOwner) Ownable(initialOwner) {
        if (initialDelay < MINIMUM_DELAY) {
            revert DelayTooShort(initialDelay, MINIMUM_DELAY);
        }
        delay = initialDelay;
    }

    /**
     * @dev Queues a transaction for future execution.
     */
    function queue(address target, uint256 value, bytes calldata data) external override onlyOwner returns (bytes32) {
        uint256 eta = block.timestamp + delay;
        bytes32 id = keccak256(abi.encode(target, value, data, eta));

        require(!queuedTransactions[id], "Transaction already queued");
        queuedTransactions[id] = true;

        emit CallQueued(id, target, value, data, eta);
        return id;
    }

    /**
     * @dev Executes a queued transaction. 
     * In the interface it's not payable, so we remove it here to match.
     */
    function execute(address target, uint256 value, bytes calldata data) external override returns (bytes memory) {
        revert("Use executeWithEta for security");
    }

    /**
     * @dev Executes a queued transaction with a specific ETA.
     */
    function executeWithEta(address target, uint256 value, bytes calldata data, uint256 eta) external payable onlyOwner nonReentrant returns (bytes memory) {
        bytes32 id = keccak256(abi.encode(target, value, data, eta));

        if (!queuedTransactions[id]) revert NotQueued(id);
        if (block.timestamp < eta) revert TimestampNotPassed(eta);
        if (block.timestamp > eta + GRACE_PERIOD) revert TransactionExpired(eta + GRACE_PERIOD);

        queuedTransactions[id] = false; // Prevent replay

        (bool success, bytes memory returnData) = target.call{value: value}(data);
        if (!success) revert ExecutionFailed();

        emit CallExecuted(id, target, value, data);
        return returnData;
    }

    /**
     * @dev Cancels a queued transaction.
     */
    function cancel(bytes32 id) external override onlyOwner {
        if (!queuedTransactions[id]) revert NotQueued(id);
        queuedTransactions[id] = false;
        emit CallCancelled(id);
    }

    /**
     * @dev Updates the execution delay.
     */
    function setDelay(uint256 newDelay) external onlyOwner {
        if (newDelay < MINIMUM_DELAY) {
            revert DelayTooShort(newDelay, MINIMUM_DELAY);
        }
        delay = newDelay;
        emit DelayChanged(newDelay);
    }

    function getDelay() external view override returns (uint256) {
        return delay;
    }
}
