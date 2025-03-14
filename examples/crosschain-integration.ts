import { ethers } from 'ethers';
import { CrossChainAdapter, ChainConfig } from '../src/crosschain/CrossChainAdapter';

/**
 * Example usage of the CrossChainAdapter for Mann Li Method cross-chain operations
 * This example demonstrates how to bridge tokens between Ethereum and Polygon
 */
async function main() {
  // Define chain configurations
  const chainConfigs: ChainConfig[] = [
    {
      chainId: 1, // Ethereum Mainnet
      rpcUrl: process.env.ETH_RPC_URL || 'https://mainnet.infura.io/v3/your-api-key',
      bridgeAddress: process.env.ETH_BRIDGE_ADDRESS || '0x1234567890123456789012345678901234567890',
      tokenAddress: process.env.ETH_TOKEN_ADDRESS || '0x0987654321098765432109876543210987654321'
    },
    {
      chainId: 137, // Polygon
      rpcUrl: process.env.POLYGON_RPC_URL || 'https://polygon-rpc.com',
      bridgeAddress: process.env.POLYGON_BRIDGE_ADDRESS || '0x2345678901234567890123456789012345678901',
      tokenAddress: process.env.POLYGON_TOKEN_ADDRESS || '0x3456789012345678901234567890123456789012'
    }
  ];

  // Initialize adapter
  const adapter = new CrossChainAdapter(chainConfigs);
  
  // Connect wallet (in production, use a secure way to provide private key)
  const privateKey = process.env.PRIVATE_KEY || '0x0000000000000000000000000000000000000000000000000000000000000000';
  adapter.connectWallet(privateKey);
  
  try {
    // Example 1: Bridge tokens from Ethereum to Polygon
    console.log('Bridging tokens from Ethereum to Polygon...');
    
    // Amount to bridge (1 token with 18 decimals)
    const amount = ethers.utils.parseEther('1.0');
    
    // Recipient address on Polygon
    const recipient = '0x4567890123456789012345678901234567890123';
    
    // Bridge tokens
    const messageId = await adapter.bridgeTokens(
      1, // Ethereum
      137, // Polygon
      recipient,
      amount
    );
    
    console.log(`Tokens bridged successfully! Message ID: ${messageId}`);
    
    // Example 2: Check message status
    console.log('Checking message status...');
    const isProcessed = await adapter.getMessageStatus(137, messageId);
    console.log(`Message processed: ${isProcessed}`);
    
    // Example 3: Get supported chains
    console.log('Getting supported chains...');
    const supportedChains = await adapter.getSupportedChains(1);
    console.log(`Supported chains: ${supportedChains.join(', ')}`);
    
    // Example 4: Get chain configuration
    console.log('Getting chain configuration...');
    const chainConfig = await adapter.getChainConfig(1, 137);
    console.log(`Chain configuration:`, chainConfig);
    
    // Example 5: Get token balance
    console.log('Getting token balance...');
    const balance = await adapter.getTokenBalance(1, recipient);
    console.log(`Token balance: ${ethers.utils.formatEther(balance)} tokens`);
    
    // Example 6: Relay a message (typically done by relayers)
    // This is a simplified example - in production, relayers would monitor events
    // and relay messages automatically
    console.log('Relaying message...');
    const tx = await adapter.relayMessage(
      1, // Source chain (Ethereum)
      137, // Target chain (Polygon)
      messageId,
      '0x1111111111111111111111111111111111111111', // Sender on Ethereum
      recipient, // Recipient on Polygon
      amount,
      Math.floor(Date.now() / 1000) // Current timestamp
    );
    
    console.log(`Message relayed successfully! Transaction hash: ${tx.hash}`);
    
  } catch (error) {
    console.error('Error:', error);
  }
}

// Run the example
main().catch(console.error);
