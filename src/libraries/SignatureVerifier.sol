// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title SignatureVerifier
 * @dev Library for verifying EIP-712 structured signatures for treasury proposals.
 * Provides protection against replay attacks via nonces and domain separators.
 * Compatible with Solidity 0.8.20.
 */
library SignatureVerifier {
    using ECDSA for bytes32;

    bytes32 public constant PROPOSAL_APPROVAL_TYPEHASH = keccak256(
        "ProposalApproval(uint256 proposalId,bool support,uint256 nonce)"
    );

    struct ProposalApproval {
        uint256 proposalId;
        bool support;
        uint256 nonce;
    }

    /**
     * @dev Computes the EIP-712 domain separator.
     */
    function computeDomainSeparator(string memory name, string memory version) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Verifies a ProposalApproval signature.
     * @param domainSeparator The EIP-712 domain separator.
     * @param approval The structured approval data.
     * @param v Recovery id.
     * @param r Output of ECDSA signature.
     * @param s Output of ECDSA signature.
     * @return The recovered signer address.
     */
    function verifyProposalApproval(
        bytes32 domainSeparator,
        ProposalApproval memory approval,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                PROPOSAL_APPROVAL_TYPEHASH,
                approval.proposalId,
                approval.support,
                approval.nonce
            )
        );

        // Standard EIP-712 hashing: keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash))
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        return digest.recover(v, r, s);
    }
}
