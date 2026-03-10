# Ares Treasury Governance Protocol

Ares is a modular, secure, and highly flexible treasury governance protocol designed for decentralized organizations. It features a layered architecture that decouples asset management, proposal registration, and time-delayed execution.

## 🚀 Key Features

- **Modular Architecture**: Separate layers for core funds, governance logic, and execution timing.
- **Proposal Lifecycle**: Robust state machine (Pending, Active, Succeeded, Queued, Executed).
- **Timelock Execution**: Mandatory 48-hour delay for all governance actions to ensure community safety.
- **Merkle Reward Claims**: Scalable, gas-efficient reward distribution to thousands of users.
- **EIP-712 Signatures**: Secure off-chain approval verification with domain separators and replay protection.
- **Security First**: Built with Solidity 0.8.20, OpenZeppelin 5.x, and comprehensive reentrancy protection.

## 📂 Project Structure

```text
ares-treasury/
├── src/
│   ├── core/           # Fund storage (ARESTreasury.sol)
│   ├── interfaces/     # Protocol interfaces (ITreasury, ITimelockEngine, etc.)
│   ├── libraries/      # Cryptographic helpers (SignatureVerifier.sol)
│   └── modules/        # Logic (ProposalManager, TimelockEngine, RewardDistributor)
├── test/
│   ├── unit/           # Functional tests for all components
│   └── security/       # Attack simulations and invariant checks
├── ARCHITECTURE.md     # System design and module separation
└── SECURITY.md         # Attack surface analysis and mitigations
```

## 📜 Documentation

For deep dives into the system design and security model, please refer to:
- 🏗️ **[Architecture Document](./ARCHITECTURE.md)**: Explains the module hierarchy and trust assumptions.
- 🛡️ **[Security Analysis](./SECURITY.md)**: Analyzes major attack surfaces and how they are mitigated.

## 🛠️ Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (Forge, Cast, Anvil)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/RuthChisom/ares-treasury.git
   cd ares-treasury
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Build the project:
   ```bash
   forge build
   ```

## 🧪 Testing

The protocol includes a rigorous test suite covering functional requirements and security invariants.

### Run All Tests
```bash
forge test
```

### Run Unit Tests Only
```bash
forge test --match-path test/unit/*
```

### Run Security Attack Simulations
```bash
forge test --match-path test/security/* -vv
```

### View Coverage Report
```bash
forge coverage
```

## ⚙️ Core Components

### ARESTreasury
The final vault that holds protocol assets. It only executes calls authorized by the `TimelockEngine`.

### ProposalManager
The entry point for governance. It tracks the status of proposals and tallies votes according to the 3-vote quorum (configurable).

### TimelockEngine
The safety gatekeeper. It enforces a 2-day `MINIMUM_DELAY` before any treasury action can be executed, providing a buffer for users to react to governance decisions.

### RewardDistributor
A scalable claim system. It allows users to claim rewards using Merkle Proofs, ensuring the protocol can distribute funds to an unlimited number of recipients without on-chain gas scaling issues.

## ⚖️ License
Distributed under the MIT License. See `LICENSE` for more information.
