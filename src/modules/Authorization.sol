// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAuthorization} from "../interfaces/IAuthorization.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Authorization is IAuthorization {
    using ECDSA for bytes32;

    function verify(address account, bytes32 digest, Sig calldata sig) public pure returns (bool) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(digest);
        address recoveredSigner = ethSignedMessageHash.recover(sig.r, sig.s, sig.v);
        return recoveredSigner == account;
    }
}
