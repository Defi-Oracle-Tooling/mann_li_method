// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { MannLiBondToken } from "./MannLiBondToken.sol";

/**
 * @title MannLiCrossChainBridge
 * @dev Bridge contract for cross-chain compatibility of Mann Li Method
 */
contract MannLiCrossChainBridge is AccessControl, ReentrancyGuard {
    // Custom errors
    error InvalidChainId(uint256 chainId);
    error InvalidAmount();
    error InvalidMessageFormat();
    error MessageAlreadyProcessed(bytes32 messageId);
    error UnauthorizedRelayer(address relayer);
    error BridgeNotEnabled();
    error TransferFailed();
    error InvalidRecipient();
    error RateLimitExceeded(uint256 nextAllowedTime);
    
    // Role definitions
    bytes32 public constant BRIDGE_ADMIN_ROLE = keccak256("BRIDGE_ADMIN_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    
    // Immutable variables
    uint256 immutable MINIMUM_TRANSFER_AMOUNT;
    uint256 immutable MAXIMUM_TRANSFER_AMOUNT;
    uint256 immutable RATE_LIMIT_PERIOD;
    
    struct ChainConfig {
        uint256 chainId;
        bool enabled;
        address remoteBridge;
        uint256 gasLimit;
        uint256 baseFee;
    }
    
    struct BridgeMessage {
        bytes32 id;
        uint256 sourceChainId;
        uint256 targetChainId;
        address sender;
        address recipient;
        uint256 amount;
        uint256 timestamp;
        bool processed;
    }
    
    // Contract references
    MannLiBondToken public bondToken;
    
    // Bridge parameters
    uint256 public totalBridgedOut;
    uint256 public totalBridgedIn;
    uint256 public lastBridgeAction;
    
    // Storage
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(bytes32 => BridgeMessage) public messages;
    mapping(bytes32 => bool) public processedMessages;
    mapping(address => uint256) public lastBridgeTimestamp;
    
    uint256[] public supportedChains;
    
    // Events
    event ChainConfigUpdated(
        uint256 indexed chainId,
        bool enabled,
        address remoteBridge,
        uint256 gasLimit,
        uint256 baseFee
    );
    
    event MessageSent(
        bytes32 indexed messageId,
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        address sender,
        address recipient,
        uint256 amount
    );
    
    event MessageReceived(
        bytes32 indexed messageId,
        uint256 indexed sourceChainId,
        uint256 indexed targetChainId,
        address sender,
        address recipient,
        uint256 amount
    );
    
    event BridgeEnabled(uint256 indexed chainId);
    event BridgeDisabled(uint256 indexed chainId);
    
    constructor(address _bondToken) {
        bondToken = MannLiBondToken(_bondToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ADMIN_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, msg.sender);
        
        MINIMUM_TRANSFER_AMOUNT = 0.1 ether;
        MAXIMUM_TRANSFER_AMOUNT = 1000 ether;
        RATE_LIMIT_PERIOD = 1 hours;
        
        lastBridgeAction = block.timestamp;
    }
    
    /**
     * @dev Adds or updates a supported chain configuration
     * @param chainId ID of the chain to add/update
     * @param remoteBridge Address of the bridge contract on the remote chain
     * @param gasLimit Gas limit for cross-chain transactions
     * @param baseFee Base fee for cross-chain transactions
     */
    function addSupportedChain(
        uint256 chainId,
        address remoteBridge,
        uint256 gasLimit,
        uint256 baseFee
    ) external onlyRole(BRIDGE_ADMIN_ROLE) {
        if (chainId == block.chainid) revert InvalidChainId(chainId);
        if (remoteBridge == address(0)) revert InvalidRecipient();
        
        if (chainConfigs[chainId].chainId != 0) {
            // Update existing chain config
            chainConfigs[chainId].remoteBridge = remoteBridge;
            chainConfigs[chainId].gasLimit = gasLimit;
            chainConfigs[chainId].baseFee = baseFee;
        } else {
            // Add new chain config
            chainConfigs[chainId] = ChainConfig({
                chainId: chainId,
                enabled: true,
                remoteBridge: remoteBridge,
                gasLimit: gasLimit,
                baseFee: baseFee
            });
            supportedChains.push(chainId);
        }
        
        emit ChainConfigUpdated(chainId, true, remoteBridge, gasLimit, baseFee);
    }
    
    /**
     * @dev Enables or disables a chain for bridging
     * @param chainId ID of the chain to update
     * @param enabled Whether the chain should be enabled
     */
    function setChainStatus(uint256 chainId, bool enabled) external onlyRole(BRIDGE_ADMIN_ROLE) {
        if (chainConfigs[chainId].chainId == 0) revert InvalidChainId(chainId);
        
        chainConfigs[chainId].enabled = enabled;
        
        if (enabled) {
            emit BridgeEnabled(chainId);
        } else {
            emit BridgeDisabled(chainId);
        }
    }
    
    /**
     * @dev Bridges tokens to another chain
     * @param targetChainId ID of the target chain
     * @param recipient Address of the recipient on the target chain
     * @param amount Amount of tokens to bridge
     * @return messageId ID of the bridge message
     */
    function bridgeTokens(
        uint256 targetChainId,
        address recipient,
        uint256 amount
    ) external nonReentrant returns (bytes32) {
        if (amount < MINIMUM_TRANSFER_AMOUNT) revert InvalidAmount();
        if (amount > MAXIMUM_TRANSFER_AMOUNT) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (chainConfigs[targetChainId].chainId == 0) revert InvalidChainId(targetChainId);
        if (!chainConfigs[targetChainId].enabled) revert BridgeNotEnabled();
        
        // Check rate limiting
        if (block.timestamp < lastBridgeTimestamp[msg.sender] + RATE_LIMIT_PERIOD) {
            revert RateLimitExceeded(lastBridgeTimestamp[msg.sender] + RATE_LIMIT_PERIOD);
        }
        
        // Lock tokens in this contract
        bool success = bondToken.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
        
        // Create message
        bytes32 messageId = keccak256(
            abi.encodePacked(
                block.chainid,
                targetChainId,
                msg.sender,
                recipient,
                amount,
                block.timestamp
            )
        );
        
        BridgeMessage storage message = messages[messageId];
        message.id = messageId;
        message.sourceChainId = block.chainid;
        message.targetChainId = targetChainId;
        message.sender = msg.sender;
        message.recipient = recipient;
        message.amount = amount;
        message.timestamp = block.timestamp;
        message.processed = false;
        
        // Update stats
        totalBridgedOut += amount;
        lastBridgeTimestamp[msg.sender] = block.timestamp;
        lastBridgeAction = block.timestamp;
        
        emit MessageSent(
            messageId,
            block.chainid,
            targetChainId,
            msg.sender,
            recipient,
            amount
        );
        
        return messageId;
    }
    
    /**
     * @dev Receives tokens from another chain
     * @param messageId ID of the bridge message
     * @param sourceChainId ID of the source chain
     * @param sender Address of the sender on the source chain
     * @param recipient Address of the recipient on this chain
     * @param amount Amount of tokens to receive
     * @param timestamp Timestamp of the original bridge request
     */
    function receiveTokens(
        bytes32 messageId,
        uint256 sourceChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint256 timestamp
    ) external nonReentrant onlyRole(RELAYER_ROLE) {
        if (processedMessages[messageId]) revert MessageAlreadyProcessed(messageId);
        if (chainConfigs[sourceChainId].chainId == 0) revert InvalidChainId(sourceChainId);
        if (!chainConfigs[sourceChainId].enabled) revert BridgeNotEnabled();
        if (recipient == address(0)) revert InvalidRecipient();
        
        // Verify message format
        bytes32 computedMessageId = keccak256(
            abi.encodePacked(
                sourceChainId,
                block.chainid,
                sender,
                recipient,
                amount,
                timestamp
            )
        );
        
        if (computedMessageId != messageId) revert InvalidMessageFormat();
        
        // Mark message as processed
        processedMessages[messageId] = true;
        
        // Try to transfer tokens from bridge reserves
        bool success = bondToken.transfer(recipient, amount);
        
        // If transfer fails (e.g., not enough tokens), mint new tokens
        if (!success) {
            // This assumes the bondToken contract has a mint function that this contract can call
            // In a real implementation, this would need proper authorization
            // bondToken.mint(recipient, amount);
            revert TransferFailed();
        }
        
        // Update stats
        totalBridgedIn += amount;
        lastBridgeAction = block.timestamp;
        
        emit MessageReceived(
            messageId,
            sourceChainId,
            block.chainid,
            sender,
            recipient,
            amount
        );
    }
    
    /**
     * @dev Gets all supported chains
     * @return Array of supported chain IDs
     */
    function getSupportedChains() external view returns (uint256[] memory) {
        return supportedChains;
    }
    
    /**
     * @dev Gets the status of a message
     * @param messageId ID of the message to check
     * @return Whether the message has been processed
     */
    function getMessageStatus(bytes32 messageId) external view returns (bool) {
        return processedMessages[messageId];
    }
    
    /**
     * @dev Gets the details of a chain configuration
     * @param chainId ID of the chain to get
     * @return enabled Whether the chain is enabled
     * @return remoteBridge Address of the bridge on the remote chain
     * @return gasLimit Gas limit for cross-chain transactions
     * @return baseFee Base fee for cross-chain transactions
     */
    function getChainConfig(uint256 chainId) external view returns (
        bool enabled,
        address remoteBridge,
        uint256 gasLimit,
        uint256 baseFee
    ) {
        ChainConfig storage config = chainConfigs[chainId];
        if (config.chainId == 0) revert InvalidChainId(chainId);
        
        return (
            config.enabled,
            config.remoteBridge,
            config.gasLimit,
            config.baseFee
        );
    }
}
