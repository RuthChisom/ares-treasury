# Architecture Document: ARES Treasury Governance Protocol

## 1. Introduction

The ARES Treasury Governance Protocol is designed to manage protocol-owned funds in a secure and transparent way. The system focuses on separating governance decisions from the actual execution of treasury actions. Instead of allowing governance to move funds directly, actions must go through a controlled pipeline that includes proposal creation, approval, a delay period, and finally execution.

The main idea behind the architecture is to reduce risk by splitting responsibilities across several independent modules. Each contract performs a specific role, which keeps the system easier to audit and limits the impact of potential bugs.

This document describes the overall architecture, how the modules interact with each other, and the security assumptions the system relies on.

---

## 2. System Architecture

The protocol follows a staged execution model. Governance actions are not executed immediately. Instead, they move through a sequence of steps designed to slow down execution and make malicious actions easier to detect.

A typical governance action flows through the following steps:

1. **Proposal Creation** – A user submits a proposal through the `ProposalManager`.
2. **Voting / Approval** – Authorized participants approve the proposal.
3. **Proposal Success** – Once the required quorum is reached (3 approvals in this prototype), the proposal becomes eligible for execution.
4. **Timelock Queue** – The proposal is sent to the `TimelockEngine`, where it must wait for a mandatory delay period.
5. **Execution** – After the delay expires, the `TimelockEngine` calls the `ARESTreasury` contract to execute the final action on-chain.

This process ensures that governance decisions cannot immediately move funds or upgrade contracts.

---

## 3. Module Separation

The protocol is organized into several layers. Each layer handles a different responsibility within the governance system.

### 3.1 Core Layer (`src/core/`)

**ARESTreasury.sol**

This contract acts as the treasury vault. It holds the protocol’s assets, including ETH and ERC20 tokens. The treasury does not contain governance logic and cannot initiate transactions on its own.

Its only job is to execute transactions when instructed by its owner. In this system, the owner is the `TimelockEngine`, meaning all treasury actions must pass through the timelock mechanism first.

---

### 3.2 Governance Layer (`src/modules/`)

**ProposalManager.sol**

This contract handles proposal creation and tracking. It records proposals, manages voting approvals, and tracks the proposal lifecycle.

Users interact with this contract when submitting proposals or approving existing ones. Once the approval threshold is reached, the proposal can be sent to the timelock for execution.

**RewardDistributor.sol**

The reward distribution module allows the protocol to distribute tokens to contributors. Since the number of recipients may be large, the contract uses a Merkle proof based claim system.

Instead of sending tokens individually, the contract stores a Merkle root representing all eligible claims. Each user can independently verify their inclusion in the tree and claim their allocation.

---

### 3.3 Execution Layer (`src/modules/`)

**TimelockEngine.sol**

The timelock contract sits between governance decisions and treasury execution. It enforces a mandatory delay period before approved proposals can be executed.

When a proposal succeeds, it is queued in the timelock. After the delay expires, the timelock can execute the transaction on the treasury contract.

This delay mechanism provides a safety window for users to review pending actions.

**Authorization.sol**

This module handles verification of structured signatures used for proposal approvals. It ensures that off-chain approvals can be validated on-chain without allowing signatures to be reused maliciously.

---

### 3.4 Library Layer (`src/libraries/`)

**SignatureVerifier.sol**

This library implements EIP-712 style structured signature verification. Using a domain separator and per-user nonces prevents several common signature attacks.

The library ensures that signatures cannot be reused across chains, contracts, or different protocol versions.

---

## 4. Security Boundaries

The protocol includes multiple layers of protection designed to isolate critical components and reduce attack surfaces.

### 4.1 Access Control

Access control is primarily enforced through ownership restrictions.

- **Treasury access** – Only the `TimelockEngine` can trigger fund movements.
- **Timelock queueing** – Only authorized governance logic can queue transactions.
- **Proposal cancellation** – Only the proposer or an authorized admin can cancel proposals before execution.

This layered control prevents direct access to treasury funds.

---

### 4.2 Proposal State Integrity

Each proposal follows a strict lifecycle. Proposals move through defined states such as `Pending`, `Active`, `Succeeded`, and `Executed`.

These states are calculated dynamically using vote counts and block numbers. This prevents attackers from manipulating proposal status through direct storage changes.

---

### 4.3 Replay and Reentrancy Protection

Several protections exist to prevent common smart contract exploits.

**Replay Protection**

The system uses unique identifiers and nonce tracking to ensure that proposals and signatures cannot be executed more than once.

**Reentrancy Protection**

The `TimelockEngine` uses reentrancy protection for execution functions. This prevents malicious receiver contracts from triggering recursive calls that could execute multiple queued transactions in a single transaction.

---

## 5. Trust Assumptions

Although the system aims to be decentralized, some trust assumptions still exist in the current design.

**Admin Privileges**

The initial admin address has authority to manage the timelock and update reward distribution roots. In a production deployment, this role should ideally be controlled by a multisig or governance contract.

**Voting Threshold**

The prototype assumes that the configured quorum (3 approvals) accurately reflects the intent of governance participants.

**Merkle Root Generation**

The reward distribution system assumes that the Merkle root generated off-chain correctly represents all eligible claims.

**Block Timestamp Accuracy**

The timelock relies on `block.timestamp` and `block.number`. While miners have limited ability to influence timestamps, the expected deviation is small and acceptable for this use case.

---

## 6. Implementation Standards

The implementation follows several commonly used development standards.

- **Solidity 0.8.20** – Uses built-in overflow checks and modern language features.
- **OpenZeppelin 5.x** – Provides tested implementations for common security primitives such as `Ownable`, `ReentrancyGuard`, `MerkleProof`, `ECDSA`, and ERC20 utilities.
- **Modular Interfaces** – Contracts communicate through defined interfaces, allowing individual components to be replaced or upgraded without redeploying the entire system.