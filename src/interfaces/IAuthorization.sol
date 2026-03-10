// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAuthorization {
    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    event Authorized(address indexed account, bytes32 indexed digest);

    function verify(address account, bytes32 digest, Sig calldata sig) external view returns (bool);
}
