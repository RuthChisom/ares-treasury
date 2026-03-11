// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRewardDistributor} from "../interfaces/IRewardDistributor.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * RewardDistributor
 * Distributes ERC20 tokens to multiple recipients using Merkle tree proofs.
 */
contract RewardDistributor is IRewardDistributor, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    bytes32 public root;

    // This is a packed array of booleans to track claims.
    // mapping(uint256 => uint256) private _claimedBitMap;
    // For simplicity in this implementation, we'll use a mapping of index to bool.
    mapping(uint256 => bool) private _isClaimed;

    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();

    /**
     * @param _token The ERC20 token to be distributed.
     * @param initialOwner The owner who can update the Merkle root.
     */
    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    /**
     * Updates the Merkle root for a new reward distribution cycle.
     * @param _newRoot The new Merkle root.
     */
    function setRoot(bytes32 _newRoot) external onlyOwner {
        emit RootUpdated(root, _newRoot);
        root = _newRoot;
    }

    /**
     * Claims rewards for a specific user.
     * @param index The index of the leaf in the Merkle tree.
     * @param account The address of the recipient.
     * @param amount The amount of tokens to claim.
     * @param proof The Merkle proof for the leaf.
     */
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata proof) external {
        if (_isClaimed[index]) revert AlreadyClaimed();

        // Verify the merkle proof.
        bytes32 leaf = keccak256(abi.encodePacked(index, account, amount));
        if (!MerkleProof.verify(proof, root, leaf)) revert InvalidProof();

        // Mark it claimed and send the token.
        _isClaimed[index] = true;
        token.safeTransfer(account, amount);

        emit Claimed(account, amount, root);
    }

    /**
     * Returns true if the index has been claimed.
     */
    function isClaimed(uint256 index) public view returns (bool) {
        return _isClaimed[index];
    }

    // Required by IRewardDistributor interface (overloaded version or adjustment)
    function claim(uint256 amount, bytes32[] calldata proof) external override {
        // This is a simplified interface version. 
        // In practice, 'index' and 'account' are needed for robust Merkle distributions.
        revert("Use claim(uint256, address, uint256, bytes32[])");
    }

    function isClaimed(address account, uint256 amount) external view override returns (bool) {
        revert("Use isClaimed(uint256)");
    }
}
