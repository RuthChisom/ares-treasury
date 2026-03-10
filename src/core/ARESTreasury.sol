// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITreasury} from "../interfaces/ITreasury.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Core treasury contract for the Ares protocol. 
 * Acts as the vault for protocol funds and the executor for governance decisions.
 */
contract ARESTreasury is ITreasury, Ownable {

    error ExecutionFailed();

    /**
     * Initializes the treasury with an initial owner (typically the TimelockEngine).
     * @param initialOwner The address that will have exclusive execution rights.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    // Allows the treasury to receive ETH.
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * Executes an authorized transaction. 
     * This can be a simple transfer, a contract call, or a call to upgrade another contract.
     * @param target The destination address (contract or wallet).
     * @param value The amount of ETH to send.
     * @param data The transaction calldata.
     * @return The result of the call.
     */
    function execute(address target, uint256 value, bytes calldata data) 
        external 
        onlyOwner 
        returns (bytes memory) 
    {
        (bool success, bytes memory result) = target.call{value: value}(data);
        
        if (!success) {
            revert ExecutionFailed();
        }

        emit Executed(target, value, data);
        return result;
    }

    /**
     * Returns the current ETH balance of the treasury.
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
