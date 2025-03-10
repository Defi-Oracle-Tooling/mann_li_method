# Mann Li Method Implementation

This project implements the Mann Li Method for financial structuring using smart contracts. It provides a comprehensive system for managing bonds, reinvestment, and contingency reserves on the blockchain.

## Core Components

- **MannLiBondToken**: ERC20-based bond token with step-down rate model
- **MannLiReinvestment**: Manages reinvestment of bond yields and buyback mechanisms
- **MannLiContingencyReserve**: Handles the 20% contingency reserve allocation for risk mitigation

## Key Features

- Step-down rate model (10% initial, 7.75% after 5 years)
- Automated coupon payments
- Reinvestment pool with configurable rates (20-50%)
- Emergency contingency reserve system
- Role-based access control

## Development

This project uses Hardhat and TypeScript for development and testing.

### Prerequisites

- Node.js >= 16
- npm or yarn

### Setup

```shell
npm install
```

### Available Commands

```shell
# Compile contracts
npm run compile

# Run tests
npm run test

# Deploy contracts (local network)
npx hardhat node
npm run deploy

# Deploy using Hardhat Ignition
npx hardhat ignition deploy ./ignition/modules/MannLiMethod.ts
```

## Project Structure

```
contracts/          # Smart contracts
├─ MannLiBondToken.sol
├─ MannLiReinvestment.sol
└─ MannLiContingencyReserve.sol

ignition/          # Deployment modules
└─ modules/
   └─ MannLiMethod.ts

test/              # Test files
```

## License

ISC
