// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IProposalManager} from "../interfaces/IProposalManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignatureVerifier} from "../libraries/SignatureVerifier.sol";

/**
 * @title ProposalManager
 * @dev Manages the lifecycle of treasury proposals, supporting transfers, calls, and upgrades.
 */
contract ProposalManager is IProposalManager, Ownable {
    using SignatureVerifier for bytes32;

    enum ProposalStatus { Pending, Approved, Queued, Executed, Cancelled }

    struct Proposal {
        uint256 id;
        address proposer;
        address target;
        uint256 value;
        bytes data;
        ProposalStatus status;
        uint256 approvals;
        mapping(address => bool) hasApproved;
    }

    uint256 public proposalCount;
    uint256 public constant QUORUM = 3; // Example quorum
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public nonces;

    event ProposalCreated(uint256 indexed id, address indexed proposer, address target, uint256 value, bytes data);
    event ProposalApproved(uint256 indexed id, address indexed approver);
    event ProposalQueued(uint256 indexed id);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCancelled(uint256 indexed id);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Creates a new treasury proposal.
     * Prevents replay using a global proposal counter.
     */
    function propose(address target, uint256 value, bytes calldata data) external returns (uint256) {
        proposalCount++;
        uint256 id = proposalCount;
        
        Proposal storage p = proposals[id];
        p.id = id;
        p.proposer = msg.sender;
        p.target = target;
        p.value = value;
        p.data = data;
        p.status = ProposalStatus.Pending;

        emit ProposalCreated(id, msg.sender, target, value, data);
        return id;
    }

    /**
     * @dev Approves a proposal. Reaches 'Approved' state once quorum is met.
     */
    function approve(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.status == ProposalStatus.Pending, "Proposal not pending");
        require(!p.hasApproved[msg.sender], "Already approved");

        p.hasApproved[msg.sender] = true;
        p.approvals++;

        emit ProposalApproved(proposalId, msg.sender);

        if (p.approvals >= QUORUM) {
            p.status = ProposalStatus.Approved;
        }
    }

    /**
     * @dev Queues an approved proposal for execution.
     */
    function queue(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(p.status == ProposalStatus.Approved, "Proposal not approved");
        
        p.status = ProposalStatus.Queued;
        emit ProposalQueued(proposalId);
    }

    /**
     * @dev Executes a queued proposal.
     */
    function execute(uint256 proposalId) external payable onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(p.status == ProposalStatus.Queued, "Proposal not queued");

        p.status = ProposalStatus.Executed;
        
        (bool success, ) = p.target.call{value: p.value}(p.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancels a proposal.
     */
    function cancel(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(msg.sender == p.proposer || msg.sender == owner(), "Unauthorized");
        require(p.status != ProposalStatus.Executed, "Already executed");

        p.status = ProposalStatus.Cancelled;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @dev Interface compatibility wrapper.
     */
    function state(uint256 proposalId) external view returns (ProposalState) {
        ProposalStatus status = proposals[proposalId].status;
        if (status == ProposalStatus.Pending) return ProposalState.Pending;
        if (status == ProposalStatus.Approved) return ProposalState.Succeeded;
        if (status == ProposalStatus.Queued) return ProposalState.Queued;
        if (status == ProposalStatus.Executed) return ProposalState.Executed;
        return ProposalState.Canceled;
    }
}
