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

## Integration and Compatibility Analysis

The Mann Li Method implements a holistic financial system with three interdependent contracts that work together:

### Contract Integration

1. **MannLiBondToken ↔ MannLiReinvestment**
   - The Reinvestment contract holds a reference to the Bond Token contract
   - Reinvestment can call `transferFrom` and `redeem` functions on the Bond Token
   - Bond buybacks involve transferring tokens from holder to Reinvestment contract, then burning them

2. **MannLiReinvestment ↔ MannLiContingencyReserve**
   - While not directly linked in code, these components share a financial relationship
   - Both contracts maintain separate ETH reserves through their `receive()` functions
   - Designed to maintain financial stability through complementary mechanisms

3. **Role-Based Access Control**
   - All contracts use OpenZeppelin's AccessControl
   - Custom roles: ISSUER_ROLE, MANAGER_ROLE, RISK_MANAGER_ROLE
   - DEFAULT_ADMIN_ROLE used across all contracts for administrative functions

### System Security Features

- All contracts include pausable functionality for emergency halting
- ReentrancyGuard used in critical functions to prevent attack vectors
- Rate limiting in the Contingency Reserve protects against rapid actions
- Emergency withdrawal mechanisms with multi-level approvals

### External Dependencies

- OpenZeppelin Contracts v4.8.20+
  - ERC20Pausable
  - AccessControl
  - ReentrancyGuard
  - Pausable

### Deployment Considerations

- Contract deployment order: MannLiBondToken → MannLiReinvestment → MannLiContingencyReserve
- MannLiReinvestment requires MannLiBondToken address at construction
- Role assignments should be configured post-deployment

## Technical Architecture

![Mann Li Method Architecture](https://via.placeholder.com/800x400?text=Mann+Li+Method+Architecture)

### MannLiBondToken

A specialized ERC20 token implementing a bond instrument with:
- 10-year maturity period
- Step-down interest rate (10% → 7.75% after 5 years)
- Transfer restrictions and lockup periods
- Bond redemption and maturity claim functions

### MannLiReinvestment

Manages reinvestment strategies for bond yields:
- Configurable reinvestment rate (20-50%)
- Bond buyback mechanism with discount rates
- Cooldown periods between buybacks for each holder
- Emergency fund withdrawal capability

### MannLiContingencyReserve

Provides risk mitigation through a reserve fund:
- Emergency mode with 3 levels of severity
- Threshold-based reserve requirements
- Daily and per-transaction withdrawal limits
- Rate-limiting for administrative actions

## Development

This project uses Foundry for development and testing.

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- Node.js >= 16
- npm or yarn

### Setup

```shell
# Install dependencies
forge install
npm install

# Build the project
forge build
```

### Available Commands

```shell
# Compile contracts
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Deploy contracts (local network)
forge script script/Deploy.s.sol --rpc-url localhost --broadcast

# Generate documentation
forge doc
```

## Project Structure

```
contracts/          # Smart contracts
├─ MannLiBondToken.sol
├─ MannLiReinvestment.sol
└─ MannLiContingencyReserve.sol

test/              # Test files
├─ MannLiBondToken.t.sol
├─ MannLiReinvestment.t.sol
└─ MannLiContingencyReserve.t.sol
```

## License

ISC
