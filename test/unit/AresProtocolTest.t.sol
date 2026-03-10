// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ProposalManager} from "../../src/modules/ProposalManager.sol";
import {TimelockEngine} from "../../src/modules/TimelockEngine.sol";
import {RewardDistributor} from "../../src/modules/RewardDistributor.sol";
import {ARESTreasury} from "../../src/core/ARESTreasury.sol";
import {SignatureVerifier} from "../../src/libraries/SignatureVerifier.sol";
import {IProposalManager} from "../../src/interfaces/IProposalManager.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AresProtocolTest is Test {
    ProposalManager proposalManager;
    TimelockEngine timelock;
    ARESTreasury treasury;
    RewardDistributor distributor;
    MockToken token;

    address admin = address(1);
    address proposer = address(2);
    address approver1 = address(3);
    address approver2 = address(4);
    address approver3 = address(5);
    address recipient = address(6);

    uint256 adminPrivateKey = 0xA11CE;

    function setUp() public {
        admin = vm.addr(adminPrivateKey);

        vm.startPrank(admin);
        
        proposalManager = new ProposalManager(admin);
        timelock = new TimelockEngine(2 days, admin);
        treasury = new ARESTreasury(address(timelock));
        
        token = new MockToken();
        distributor = new RewardDistributor(address(token), admin);
        
        token.mint(address(distributor), 1000 ether);
        token.mint(address(timelock), 1000 ether); // Give timelock some tokens for direct execution test
        vm.deal(address(treasury), 10 ether);
        vm.deal(address(proposalManager), 10 ether);
        
        vm.stopPrank();
    }

    // --- 1. Proposal Lifecycle Tests ---

    function testProposalLifecycle() public {
        vm.prank(proposer);
        uint256 propId = proposalManager.propose(recipient, 1 ether, "", "Test Proposal");

        assertEq(uint256(proposalManager.state(propId)), uint256(IProposalManager.ProposalState.Pending));

        // Warp to next block to make it Active
        vm.roll(block.number + 1);

        // Votes
        vm.prank(approver1);
        proposalManager.castVote(propId, true);
        vm.prank(approver2);
        proposalManager.castVote(propId, true);
        vm.prank(approver3);
        proposalManager.castVote(propId, true);

        // Warp to end of voting period
        vm.roll(block.number + 101);

        assertEq(uint256(proposalManager.state(propId)), uint256(IProposalManager.ProposalState.Succeeded));

        // Queue
        vm.prank(admin);
        proposalManager.queue(propId);

        // Execute 
        vm.prank(admin);
        proposalManager.execute{value: 0}(propId);
        assertEq(uint256(proposalManager.state(propId)), uint256(IProposalManager.ProposalState.Executed));
    }

    // --- 2. Signature Verification Tests ---

    function testSignatureVerification() public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("AresProtocol")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        SignatureVerifier.ProposalApproval memory approval = SignatureVerifier.ProposalApproval({
            proposalId: 1,
            support: true,
            nonce: 0
        });

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("ProposalApproval(uint256 proposalId,bool support,uint256 nonce)"),
                approval.proposalId,
                approval.support,
                approval.nonce
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digest);

        address recovered = SignatureVerifier.verifyProposalApproval(
            domainSeparator,
            approval,
            v, r, s
        );

        assertEq(recovered, admin);
    }

    // --- 3. Timelock Queue and Execution Tests ---

    function testTimelockExecution() public {
        address target = address(token);
        bytes memory data = abi.encodeWithSelector(ERC20.transfer.selector, recipient, 100);
        
        vm.startPrank(admin);
        bytes32 id = timelock.queue(target, 0, data);
        uint256 eta = block.timestamp + timelock.delay();

        vm.expectRevert(); // Too early
        timelock.executeWithEta(target, 0, data, eta);

        vm.warp(eta + 1);
        timelock.executeWithEta(target, 0, data, eta);
        vm.stopPrank();

        assertFalse(timelock.queuedTransactions(id));
    }

    // --- 4. Reward Claiming Tests ---

    function testRewardClaiming() public {
        // Simple tree with 1 leaf: [index: 0, account: recipient, amount: 100]
        uint256 index = 0;
        uint256 amount = 100;
        bytes32 leaf = keccak256(abi.encodePacked(index, recipient, amount));
        
        // Root is just the leaf in a 1-node tree
        bytes32 root = leaf;
        
        vm.prank(admin);
        distributor.setRoot(root);

        bytes32[] memory proof = new bytes32[](0); // Empty proof for 1-node tree

        uint256 balanceBefore = token.balanceOf(recipient);
        
        vm.prank(recipient);
        distributor.claim(index, recipient, amount, proof);
        
        uint256 balanceAfter = token.balanceOf(recipient);
        assertEq(balanceAfter - balanceBefore, amount);
        assertTrue(distributor.isClaimed(index));
    }
}
