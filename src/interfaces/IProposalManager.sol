// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProposalManager {
    enum ProposalState { Pending, Active, Defeated, Succeeded, Queued, Executed, Canceled, Expired }

    struct Proposal {
        uint256 id;
        address proposer;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        address target;
        uint256 value;
        bytes data;
    }

    event ProposalCreated(uint256 indexed id, address indexed proposer, address target, uint256 value, bytes data, string description);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    function propose(address target, uint256 value, bytes calldata data, string calldata description) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function state(uint256 proposalId) external view returns (ProposalState);
}
