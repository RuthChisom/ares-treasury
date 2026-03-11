// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IProposalManager} from "../interfaces/IProposalManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignatureVerifier} from "../libraries/SignatureVerifier.sol";

/**
 * ProposalManager
 * Manages the lifecycle of treasury proposals, supporting transfers, calls, and upgrades.
 */
contract ProposalManager is IProposalManager, Ownable {
    using SignatureVerifier for bytes32;

    uint256 public proposalCount;
    uint256 public constant QUORUM = 3; // Example quorum
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public nonces;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * Creates a new treasury proposal.
     * Prevents replay using a global proposal counter.
     */
    function propose(address target, uint256 value, bytes calldata data, string calldata description) external override returns (uint256) {
        proposalCount++;
        uint256 id = proposalCount;
        
        Proposal storage p = proposals[id];
        p.id = id;
        p.proposer = msg.sender;
        p.target = target;
        p.value = value;
        p.data = data;
        p.executed = false;
        p.canceled = false;
        p.startBlock = block.number;
        p.endBlock = block.number + 100; // 100 blocks

        emit ProposalCreated(id, msg.sender, target, value, data, description);
        return id;
    }

    // Approves a proposal. Interface uses castVote for logic.
    function castVote(uint256 proposalId, bool support) external override {
        require(state(proposalId) == ProposalState.Active, "Proposal not active");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        Proposal storage p = proposals[proposalId];
        if (support) {
            p.forVotes++;
        } else {
            p.againstVotes++;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit VoteCast(msg.sender, proposalId, support, 1);
    }

    // Queues an approved proposal for execution.
    function queue(uint256 proposalId) external onlyOwner {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        // State will become Queued if the logic supports it. 
        // For now let's just use it to mark progress.
    }

    // Executes a succeeded proposal.
    function execute(uint256 proposalId) external payable onlyOwner {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");

        Proposal storage p = proposals[proposalId];
        p.executed = true;
        
        (bool success, ) = p.target.call{value: p.value}(p.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    // Cancels a proposal.
    function cancel(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(msg.sender == p.proposer || msg.sender == owner(), "Unauthorized");
        require(!p.executed, "Already executed");

        p.canceled = true;
        // Interface doesn't have cancel event but let's just skip it or add if needed.
    }

    // Returns the current state of a proposal.
    function state(uint256 proposalId) public view override returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.number <= p.startBlock) return ProposalState.Pending;
        if (block.number <= p.endBlock) return ProposalState.Active;
        if (p.forVotes < QUORUM) return ProposalState.Defeated; // Using QUORUM as threshold
        if (p.againstVotes >= p.forVotes) return ProposalState.Defeated;
        return ProposalState.Succeeded;
    }
}
