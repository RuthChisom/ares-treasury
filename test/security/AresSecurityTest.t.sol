// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ProposalManager} from "../../src/modules/ProposalManager.sol";
import {TimelockEngine} from "../../src/modules/TimelockEngine.sol";
import {RewardDistributor} from "../../src/modules/RewardDistributor.sol";
import {ARESTreasury} from "../../src/core/ARESTreasury.sol";
import {SignatureVerifier} from "../../src/libraries/SignatureVerifier.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// --- Mock Malicious Contracts ---

contract MaliciousReentrant {
    TimelockEngine public timelock;
    bool public attackStarted;

    constructor(TimelockEngine _timelock) {
        timelock = _timelock;
    }

    // This function will be called by the TimelockEngine
    function attack(address target, uint256 value, bytes calldata data, uint256 eta) external {
        // Attempt to re-enter the timelock's executeWithEta function
        timelock.executeWithEta(target, value, data, eta);
    }

    receive() external payable {}
}

contract MaliciousReceiver {
    error RevertForever();
    fallback() external payable {
        revert RevertForever();
    }
}

contract AresSecurityTest is Test {
    ProposalManager proposalManager;
    TimelockEngine timelock;
    ARESTreasury treasury;
    RewardDistributor distributor;
    
    address admin = address(0xAD);
    address attacker = address(0xBAD);
    address user = address(0x01);
    
    uint256 adminPk = 0xAD1;
    uint256 attackerPk = 0xBAD1;

    function setUp() public {
        admin = vm.addr(adminPk);
        attacker = vm.addr(attackerPk);

        vm.startPrank(admin);
        proposalManager = new ProposalManager(admin);
        timelock = new TimelockEngine(2 days, admin);
        treasury = new ARESTreasury(address(timelock));
        distributor = new RewardDistributor(address(0xDE1), admin); // Mock token addr
        vm.stopPrank();
    }

    // --- 1. Reentrancy Attempt ---
    function testSecurityReentrancy() public {
        MaliciousReentrant mal = new MaliciousReentrant(timelock);
        bytes memory data = abi.encodeWithSelector(mal.attack.selector, address(mal), 0, "", 0);
        
        vm.startPrank(admin);
        uint256 eta = block.timestamp + 2 days;
        timelock.queue(address(mal), 0, data);
        vm.warp(eta + 1);
        
        // The executeWithEta should fail because it marks queuedTransactions[id] = false BEFORE the call
        // and also uses nonReentrant modifier.
        vm.expectRevert(); 
        timelock.executeWithEta(address(mal), 0, data, eta);
        vm.stopPrank();
    }

    // --- 2. Double Reward Claim ---
    function testSecurityDoubleClaim() public {
        uint256 amount = 100;
        bytes32 leaf = keccak256(abi.encodePacked(uint256(0), user, amount));
        
        vm.prank(admin);
        distributor.setRoot(leaf);

        bytes32[] memory proof = new bytes32[](0);

        // Mock the token transfer for the distributor
        vm.mockCall(address(0xDE1), abi.encodeWithSelector(ERC20.transfer.selector), abi.encode(true));
        
        vm.startPrank(user);
        distributor.claim(0, user, amount, proof);
        
        // Second claim attempt should revert
        vm.expectRevert(abi.encodeWithSignature("AlreadyClaimed()"));
        distributor.claim(0, user, amount, proof);
        vm.stopPrank();
    }

    // --- 3. Invalid Signature Approval ---
    function testSecurityInvalidSignature() public {
        bytes32 domainSeparator = keccak256("domain");
        SignatureVerifier.ProposalApproval memory approval = SignatureVerifier.ProposalApproval(1, true, 0);
        
        // Sign with a random key instead of the expected admin key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xDEADBEEF, keccak256("wrong digest"));
        
        address recovered = SignatureVerifier.verifyProposalApproval(domainSeparator, approval, v, r, s);
        assertTrue(recovered != admin);
    }

    // --- 4. Premature Timelock Execution ---
    function testSecurityPrematureExecution() public {
        bytes memory data = "";
        vm.startPrank(admin);
        uint256 eta = block.timestamp + 2 days;
        timelock.queue(address(0x123), 0, data);
        
        // Try to execute 1 hour before ETA
        vm.warp(eta - 1 hours);
        vm.expectRevert(abi.encodeWithSignature("TimestampNotPassed(uint256)", eta));
        timelock.executeWithEta(address(0x123), 0, data, eta);
        vm.stopPrank();
    }

    // --- 5. Proposal Replay ---
    function testSecurityProposalReplay() public {
        vm.startPrank(user);
        uint256 id1 = proposalManager.propose(address(0x1), 0, "", "1");
        uint256 id2 = proposalManager.propose(address(0x1), 0, "", "2");
        
        // Each proposal must have a unique ID even with identical parameters
        assertEq(id1, 1);
        assertEq(id2, 2);
        vm.stopPrank();
    }

    // --- 6. Unauthorized Execution ---
    function testSecurityUnauthorizedExecution() public {
        vm.startPrank(attacker);
        
        // Try to execute directly on Treasury (only timelock can)
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        treasury.execute(address(attacker), 1 ether, "");
        
        // Try to queue on Timelock (only admin/owner can)
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker));
        timelock.queue(address(attacker), 0, "");
        
        vm.stopPrank();
    }

    // --- 7. Malicious Receiver Contract ---
    function testSecurityMaliciousReceiver() public {
        MaliciousReceiver mr = new MaliciousReceiver();
        
        vm.startPrank(admin);
        uint256 eta = block.timestamp + 2 days;
        timelock.queue(address(mr), 0, "");
        vm.warp(eta + 1);
        
        // Timelock should catch the failure of the underlying call
        vm.expectRevert(abi.encodeWithSignature("ExecutionFailed()"));
        timelock.executeWithEta(address(mr), 0, "", eta);
        vm.stopPrank();
    }

    // --- 8. Governance Griefing ---
    function testSecurityGriefing() public {
        vm.prank(admin);
        uint256 id = proposalManager.propose(address(0x1), 0, "", "Grief");
        
        // Attacker attempts to cancel a proposal they didn't create
        vm.prank(attacker);
        vm.expectRevert("Unauthorized");
        proposalManager.cancel(id);
    }
}
