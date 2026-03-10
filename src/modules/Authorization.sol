// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAuthorization} from "../interfaces/IAuthorization.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Authorization is IAuthorization {
    using ECDSA for bytes32;

    function verify(address account, bytes32 digest, Sig calldata sig) public pure returns (bool) {
        // Equivalent to MessageHashUtils.toEthSignedMessageHash(digest)
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        address recoveredSigner = ethSignedMessageHash.recover(sig.v, sig.r, sig.s);
        return recoveredSigner == account;
    }
}
