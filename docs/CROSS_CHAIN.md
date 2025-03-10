# Mann Li Method Cross-Chain Compatibility

This document provides an overview of the cross-chain compatibility features of the Mann Li Method protocol, including architecture, supported chains, and integration guidelines.

## Overview

The Mann Li Method protocol supports cross-chain operations through a bridge mechanism that allows bond tokens to be transferred between different blockchain networks. This enables users to leverage the benefits of the Mann Li Method across multiple ecosystems.

## Architecture

The cross-chain functionality is implemented through the following components:

1. **MannLiCrossChainBridge Contract**: A Solidity smart contract deployed on each supported blockchain that handles the locking, unlocking, and verification of token transfers.

2. **CrossChainAdapter**: A TypeScript library that provides a convenient interface for interacting with the bridge contracts across different chains.

3. **Relayer Network**: A network of trusted relayers that monitor events on source chains and relay messages to target chains.

## Supported Chains

The Mann Li Method currently supports the following blockchain networks:

- Ethereum Mainnet (Chain ID: 1)
- Polygon (Chain ID: 137)

Additional chains can be added by the bridge administrators.

## Security Model

The cross-chain bridge employs the following security measures:

1. **Role-Based Access Control**: Only authorized relayers can process incoming messages.

2. **Message Verification**: Each message is cryptographically verified to ensure its authenticity.

3. **Rate Limiting**: Transfers are rate-limited to prevent abuse.

4. **Transfer Limits**: Minimum and maximum transfer amounts are enforced.

5. **Chain Enablement**: Administrators can enable or disable specific chains in case of security concerns.

## Integration Guide

### Using the CrossChainAdapter

The `CrossChainAdapter` class provides a convenient way to interact with the cross-chain functionality:

```typescript
import { ethers } from 'ethers';
import { CrossChainAdapter, ChainConfig } from '../src/crosschain/CrossChainAdapter';

// Define chain configurations
const chainConfigs: ChainConfig[] = [
  {
    chainId: 1, // Ethereum Mainnet
    rpcUrl: 'https://mainnet.infura.io/v3/your-api-key',
    bridgeAddress: '0x1234567890123456789012345678901234567890',
    tokenAddress: '0x0987654321098765432109876543210987654321'
  },
  {
    chainId: 137, // Polygon
    rpcUrl: 'https://polygon-rpc.com',
    bridgeAddress: '0x2345678901234567890123456789012345678901',
    tokenAddress: '0x3456789012345678901234567890123456789012'
  }
];

// Initialize adapter
const adapter = new CrossChainAdapter(chainConfigs);

// Connect wallet
adapter.connectWallet('your-private-key');

// Bridge tokens from Ethereum to Polygon
const amount = ethers.utils.parseEther('1.0');
const recipient = '0x4567890123456789012345678901234567890123';
const messageId = await adapter.bridgeTokens(1, 137, recipient, amount);
```

### Direct Contract Interaction

For more advanced use cases, you can interact directly with the bridge contracts:

```solidity
// Approve token transfer
IERC20(tokenAddress).approve(bridgeAddress, amount);

// Bridge tokens
bytes32 messageId = IMannLiCrossChainBridge(bridgeAddress).bridgeTokens(
    targetChainId,
    recipient,
    amount
);
```

## Relayer Operation

Relayers are responsible for monitoring events on source chains and relaying messages to target chains. To operate a relayer:

1. Obtain the `RELAYER_ROLE` from the bridge administrator.
2. Monitor `MessageSent` events on all supported chains.
3. When a message is detected, call `receiveTokens` on the target chain's bridge contract.

## Error Handling

The bridge contracts use custom errors to provide clear information about failure conditions:

- `InvalidChainId`: The specified chain ID is not supported.
- `InvalidAmount`: The transfer amount is outside the allowed range.
- `InvalidMessageFormat`: The message format is invalid.
- `MessageAlreadyProcessed`: The message has already been processed.
- `UnauthorizedRelayer`: The caller is not an authorized relayer.
- `BridgeNotEnabled`: The bridge for the specified chain is not enabled.
- `TransferFailed`: The token transfer failed.
- `InvalidRecipient`: The recipient address is invalid.
- `RateLimitExceeded`: The rate limit for transfers has been exceeded.

## Governance

The cross-chain bridge is governed by administrators who hold the `BRIDGE_ADMIN_ROLE`. They can:

1. Add or update supported chains.
2. Enable or disable specific chains.
3. Grant or revoke the `RELAYER_ROLE` to trusted entities.

## Future Enhancements

Planned enhancements to the cross-chain functionality include:

1. Support for additional blockchain networks.
2. Decentralized relayer network.
3. Cross-chain governance mechanisms.
4. Enhanced security features.

## Monitoring and Alerts

The cross-chain bridge emits events that can be monitored for operational and security purposes:

- `ChainConfigUpdated`: Emitted when a chain configuration is updated.
- `MessageSent`: Emitted when tokens are bridged from the source chain.
- `MessageReceived`: Emitted when tokens are received on the target chain.
- `BridgeEnabled`: Emitted when a bridge is enabled.
- `BridgeDisabled`: Emitted when a bridge is disabled.

These events should be monitored to ensure the proper operation of the cross-chain functionality.
