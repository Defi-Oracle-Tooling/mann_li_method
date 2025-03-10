# Mann Li Method - Deployment Guide

## Prerequisites
- Node.js (v14+)
- Foundry (forge, anvil, cast)
- Ethereum wallet with sufficient funds
- Infura or Alchemy API key

## Deployment Steps

### 1. Clone the Repository
```bash
git clone https://github.com/Defi-Oracle-Tooling/mann_li_method.git
cd mann_li_method
```

### 2. Install Dependencies
```bash
forge install
```

### 3. Configure Environment
Create a `.env` file with the following variables:
```
PRIVATE_KEY=your_private_key
INFURA_API_KEY=your_infura_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 4. Compile Contracts
```bash
forge build
```

### 5. Deploy to Testnet (Goerli)
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url https://goerli.infura.io/v3/$INFURA_API_KEY --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

### 6. Deploy to Mainnet
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url https://mainnet.infura.io/v3/$INFURA_API_KEY --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

### 7. Verify Deployment
After deployment, verify that:
- All contracts are deployed successfully
- Contract addresses are recorded
- Roles are assigned correctly
- Initial parameters are set correctly

## Post-Deployment Configuration
- Grant ISSUER_ROLE to appropriate addresses
- Grant RATE_MANAGER_ROLE to appropriate addresses
- Grant RISK_MANAGER_ROLE to appropriate addresses
- Set initial bond series parameters
- Set reinvestment parameters
- Set contingency reserve parameters
