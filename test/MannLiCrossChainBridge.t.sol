// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MannLiCrossChainBridge.sol";
import "../contracts/MannLiBondToken.sol";

contract MannLiCrossChainBridgeTest is Test {
    MannLiBondToken bondToken;
    MannLiCrossChainBridge bridge;
    
    address admin = address(1);
    address relayer = address(2);
    address user1 = address(3);
    address user2 = address(4);
    
    uint256 chainId1 = 1; // Ethereum Mainnet
    uint256 chainId2 = 137; // Polygon
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy contracts
        bondToken = new MannLiBondToken();
        bridge = new MannLiCrossChainBridge(address(bondToken));
        
        // Grant roles
        bondToken.grantRole(bondToken.ISSUER_ROLE(), address(bridge));
        bondToken.grantRole(bondToken.ISSUER_ROLE(), admin);
        bridge.grantRole(bridge.RELAYER_ROLE(), relayer);
        
        // Configure chains
        bridge.addSupportedChain(
            chainId1,
            address(0x1), // Mock remote bridge address
            300000, // Gas limit
            1 gwei // Base fee
        );
        
        bridge.addSupportedChain(
            chainId2,
            address(0x2), // Mock remote bridge address
            500000, // Gas limit
            5 gwei // Base fee
        );
        
        // Issue some bonds to user1
        bondToken.issueBond(user1, 1000 ether);
        
        // Issue some bonds to bridge for receiving tokens
        bondToken.issueBond(address(bridge), 1000 ether);
        
        vm.stopPrank();
        
        // Approve bridge to transfer tokens
        vm.prank(user1);
        bondToken.approve(address(bridge), type(uint256).max);
    }
    
    function test_AddSupportedChain() public {
        uint256 newChainId = 56; // BSC
        
        vm.prank(admin);
        bridge.addSupportedChain(
            newChainId,
            address(0x3),
            400000,
            2 gwei
        );
        
        uint256[] memory chains = bridge.getSupportedChains();
        bool found = false;
        
        for (uint i = 0; i < chains.length; i++) {
            if (chains[i] == newChainId) {
                found = true;
                break;
            }
        }
        
        assertTrue(found, "New chain not found in supported chains");
        
        (
            bool enabled,
            address remoteBridge,
            uint256 gasLimit,
            uint256 baseFee
        ) = bridge.getChainConfig(newChainId);
        
        assertTrue(enabled);
        assertEq(remoteBridge, address(0x3));
        assertEq(gasLimit, 400000);
        assertEq(baseFee, 2 gwei);
    }
    
    function test_BridgeTokens() public {
        uint256 amount = 100 ether;
        
        // Bridge tokens
        vm.prank(user1);
        bytes32 messageId = bridge.bridgeTokens(
            chainId2,
            user2,
            amount
        );
        
        // Verify token transfer
        assertEq(bondToken.balanceOf(address(bridge)), 1000 ether + amount);
        assertEq(bondToken.balanceOf(user1), 900 ether);
        
        // Verify message storage
        (
            bytes32 id,
            uint256 sourceChainId,
            uint256 targetChainId,
            address sender,
            address recipient,
            uint256 msgAmount,
            uint256 timestamp,
            bool processed
        ) = bridge.messages(messageId);
        
        assertEq(id, messageId);
        assertEq(sourceChainId, block.chainid);
        assertEq(targetChainId, chainId2);
        assertEq(sender, user1);
        assertEq(recipient, user2);
        assertEq(msgAmount, amount);
        assertFalse(processed);
    }
    
    function test_DisableChain() public {
        // Disable chain
        vm.prank(admin);
        bridge.setChainStatus(chainId2, false);
        
        // Try to bridge tokens to disabled chain
        vm.expectRevert(abi.encodeWithSelector(
            MannLiCrossChainBridge.BridgeNotEnabled.selector
        ));
        vm.prank(user1);
        bridge.bridgeTokens(chainId2, user2, 100 ether);
        
        // Re-enable chain
        vm.prank(admin);
        bridge.setChainStatus(chainId2, true);
        
        // Now bridging should work
        vm.prank(user1);
        bytes32 messageId = bridge.bridgeTokens(chainId2, user2, 100 ether);
        assertTrue(messageId != bytes32(0));
    }
    
    function test_ReceiveTokens() public {
        uint256 amount = 100 ether;
        uint256 timestamp = block.timestamp;
        
        // Create message ID as it would be created on the source chain
        bytes32 messageId = keccak256(
            abi.encodePacked(
                chainId2, // source chain
                block.chainid, // target chain
                user1, // sender
                user2, // recipient
                amount,
                timestamp
            )
        );
        
        // Receive tokens as relayer
        vm.prank(relayer);
        bridge.receiveTokens(
            messageId,
            chainId2,
            user1,
            user2,
            amount,
            timestamp
        );
        
        // Verify message is marked as processed
        assertTrue(bridge.processedMessages(messageId));
        
        // Verify tokens were transferred to recipient
        assertEq(bondToken.balanceOf(user2), amount);
        
        // Try to process the same message again
        vm.expectRevert(abi.encodeWithSelector(
            MannLiCrossChainBridge.MessageAlreadyProcessed.selector,
            messageId
        ));
        vm.prank(relayer);
        bridge.receiveTokens(
            messageId,
            chainId2,
            user1,
            user2,
            amount,
            timestamp
        );
    }
    
    function test_OnlyRelayerCanReceiveTokens() public {
        uint256 amount = 100 ether;
        uint256 timestamp = block.timestamp;
        
        bytes32 messageId = keccak256(
            abi.encodePacked(
                chainId2,
                block.chainid,
                user1,
                user2,
                amount,
                timestamp
            )
        );
        
        // Try to receive tokens as non-relayer
        vm.expectRevert();
        vm.prank(user1);
        bridge.receiveTokens(
            messageId,
            chainId2,
            user1,
            user2,
            amount,
            timestamp
        );
    }
    
    function test_RateLimiting() public {
        uint256 amount = 100 ether;
        
        // Bridge tokens
        vm.prank(user1);
        bridge.bridgeTokens(
            chainId2,
            user2,
            amount
        );
        
        // Try to bridge again immediately (should fail due to rate limiting)
        vm.expectRevert(abi.encodeWithSelector(
            MannLiCrossChainBridge.RateLimitExceeded.selector,
            block.timestamp + 1 hours
        ));
        vm.prank(user1);
        bridge.bridgeTokens(
            chainId2,
            user2,
            amount
        );
        
        // Wait for rate limit to expire
        vm.warp(block.timestamp + 1 hours + 1 minutes);
        
        // Now bridging should work
        vm.prank(user1);
        bytes32 messageId = bridge.bridgeTokens(
            chainId2,
            user2,
            amount
        );
        assertTrue(messageId != bytes32(0));
    }
    
    function test_InvalidMessageFormat() public {
        uint256 amount = 100 ether;
        uint256 timestamp = block.timestamp;
        
        // Create message ID with incorrect format
        bytes32 messageId = keccak256(
            abi.encodePacked(
                chainId2,
                block.chainid,
                user1,
                user2,
                amount,
                timestamp
            )
        );
        
        // Try to receive tokens with incorrect message format
        vm.expectRevert(abi.encodeWithSelector(
            MannLiCrossChainBridge.InvalidMessageFormat.selector
        ));
        vm.prank(relayer);
        bridge.receiveTokens(
            messageId,
            chainId2,
            user2, // Incorrect sender
            user2,
            amount,
            timestamp
        );
    }
    
    function test_TransferLimits() public {
        // Try to bridge less than minimum amount
        vm.expectRevert(abi.encodeWithSelector(
            MannLiCrossChainBridge.InvalidAmount.selector
        ));
        vm.prank(user1);
        bridge.bridgeTokens(
            chainId2,
            user2,
            0.01 ether // Less than minimum
        );
        
        // Try to bridge more than maximum amount
        vm.expectRevert(abi.encodeWithSelector(
            MannLiCrossChainBridge.InvalidAmount.selector
        ));
        vm.prank(user1);
        bridge.bridgeTokens(
            chainId2,
            user2,
            2000 ether // More than maximum
        );
    }
}
