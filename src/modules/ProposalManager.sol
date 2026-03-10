// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IProposalManager} from "../interfaces/IProposalManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ProposalManager is IProposalManager, Ownable {
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function propose(address target, uint256 value, bytes calldata data, string calldata description) external returns (uint256) {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            startBlock: block.number,
            endBlock: block.number + 100, // 100 blocks for voting
            forVotes: 0,
            againstVotes: 0,
            executed: false,
            canceled: false,
            target: target,
            value: value,
            data: data
        });

        emit ProposalCreated(proposalCount, msg.sender, target, value, data, description);
        return proposalCount;
    }

    function castVote(uint256 proposalId, bool support) external {
        require(state(proposalId) == ProposalState.Active, "Proposal not active");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        Proposal storage proposal = proposals[proposalId];
        uint256 weight = 1; // Simplify to 1 per address for prototype

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) return ProposalState.Canceled;
        if (proposal.executed) return ProposalState.Executed;
        if (block.number <= proposal.startBlock) return ProposalState.Pending;
        if (block.number <= proposal.endBlock) return ProposalState.Active;
        if (proposal.forVotes <= proposal.againstVotes) return ProposalState.Defeated;
        return ProposalState.Succeeded;
    }

    function execute(uint256 proposalId) external onlyOwner {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
        // Execution of proposal target/data would happen here via Timelock or Treasury.
    }
}
