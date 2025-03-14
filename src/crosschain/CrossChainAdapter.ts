import { ethers } from 'ethers';

export interface ChainConfig {
  chainId: number;
  rpcUrl: string;
  bridgeAddress: string;
  tokenAddress: string;
}

export class CrossChainAdapter {
  private providers: Map<number, ethers.JsonRpcProvider> = new Map();
  private bridges: Map<number, ethers.Contract> = new Map();
  private tokens: Map<number, ethers.Contract> = new Map();
  private chainConfigs: Map<number, ChainConfig> = new Map();
  private wallet: ethers.Wallet | null = null;

  constructor(private readonly configs: ChainConfig[]) {
    this.initialize();
  }

  private initialize(): void {
    for (const config of this.configs) {
      const provider = new ethers.JsonRpcProvider(config.rpcUrl);
      this.providers.set(config.chainId, provider);
      this.chainConfigs.set(config.chainId, config);
    }
  }

  public connectWallet(privateKey: string): void {
    for (const [chainId, provider] of this.providers.entries()) {
      const wallet = new ethers.Wallet(privateKey, provider);
      const config = this.chainConfigs.get(chainId)!;
      
      // Bridge ABI - simplified for this example
      const bridgeAbi = [
        "function bridgeTokens(uint256 targetChainId, address recipient, uint256 amount) external returns (bytes32)",
        "function receiveTokens(bytes32 messageId, uint256 sourceChainId, address sender, address recipient, uint256 amount, uint256 timestamp) external",
        "function getMessageStatus(bytes32 messageId) external view returns (bool)",
        "function getSupportedChains() external view returns (uint256[])",
        "function getChainConfig(uint256 chainId) external view returns (bool enabled, address remoteBridge, uint256 gasLimit, uint256 baseFee)",
        "event MessageSent(bytes32 indexed messageId, uint256 indexed sourceChainId, uint256 indexed targetChainId, address sender, address recipient, uint256 amount)"
      ];
      
      // Token ABI - simplified for this example
      const tokenAbi = [
        "function approve(address spender, uint256 amount) external returns (bool)",
        "function balanceOf(address account) external view returns (uint256)",
        "function transfer(address recipient, uint256 amount) external returns (bool)",
        "function transferFrom(address sender, address recipient, uint256 amount) external returns (bool)"
      ];
      
      const bridge = new ethers.Contract(config.bridgeAddress, bridgeAbi, wallet);
      const token = new ethers.Contract(config.tokenAddress, tokenAbi, wallet);
      
      this.bridges.set(chainId, bridge);
      this.tokens.set(chainId, token);
    }
    
    // Store wallet for later use
    this.wallet = new ethers.Wallet(privateKey);
  }

  public async bridgeTokens(
    sourceChainId: number,
    targetChainId: number,
    recipient: string,
    amount: bigint
  ): Promise<string> {
    const bridge = this.bridges.get(sourceChainId);
    const token = this.tokens.get(sourceChainId);
    
    if (!bridge || !token) {
      throw new Error(`Chain ${sourceChainId} not configured`);
    }
    
    // Approve token transfer
    const approveTx = await token.approve(bridge.address, amount);
    await approveTx.wait();
    
    // Bridge tokens
    const tx = await bridge.bridgeTokens(targetChainId, recipient, amount);
    const receipt = await tx.wait();
    
    // Extract message ID from event logs
    const event = receipt.events?.find((e: any) => e.event === 'MessageSent');
    if (!event) {
      throw new Error('MessageSent event not found in transaction receipt');
    }
    
    return event.args?.messageId;
  }

  public async getMessageStatus(chainId: number, messageId: string): Promise<boolean> {
    const bridge = this.bridges.get(chainId);
    
    if (!bridge) {
      throw new Error(`Chain ${chainId} not configured`);
    }
    
    return bridge.getMessageStatus(messageId);
  }

  public async getSupportedChains(chainId: number): Promise<number[]> {
    const bridge = this.bridges.get(chainId);
    
    if (!bridge) {
      throw new Error(`Chain ${chainId} not configured`);
    }
    
    return bridge.getSupportedChains();
  }

  public async relayMessage(
    sourceChainId: number,
    targetChainId: number,
    messageId: string,
    sender: string,
    recipient: string,
    amount: bigint,
    timestamp: number
  ): Promise<ethers.ContractTransaction> {
    const targetBridge = this.bridges.get(targetChainId);
    
    if (!targetBridge) {
      throw new Error(`Target chain ${targetChainId} not configured`);
    }
    
    return targetBridge.receiveTokens(
      messageId,
      sourceChainId,
      sender,
      recipient,
      amount,
      timestamp
    );
  }
  
  public async getChainConfig(chainId: number, targetChainId: number): Promise<{
    enabled: boolean;
    remoteBridge: string;
    gasLimit: bigint;
    baseFee: bigint;
  }> {
    const bridge = this.bridges.get(chainId);
    
    if (!bridge) {
      throw new Error(`Chain ${chainId} not configured`);
    }
    
    return bridge.getChainConfig(targetChainId);
  }
  
  public async getTokenBalance(chainId: number, address: string): Promise<bigint> {
    const token = this.tokens.get(chainId);
    
    if (!token) {
      throw new Error(`Chain ${chainId} not configured`);
    }
    
    return token.balanceOf(address);
  }
}
