# Mann Li Method - Technical Documentation

## Overview
The Mann Li Method is a decentralized financial structuring system implemented as a set of smart contracts on the Ethereum blockchain. It enables the issuance, management, and redemption of bonds with step-down rate models.

## Smart Contracts

### MannLiBondToken
The core contract that implements the ERC20 token standard with additional bond functionality.

#### Key Features
- Bond issuance with configurable parameters
- Multiple bond series support
- Step-down rate model
- Transfer restrictions
- Maturity claiming
- Early redemption with penalty

#### Roles
- DEFAULT_ADMIN_ROLE: Can grant/revoke roles and pause/unpause the contract
- ISSUER_ROLE: Can issue bonds, pay coupons, and redeem bonds
- RATE_MANAGER_ROLE: Can create and manage bond series and adjust rates

### MannLiReinvestment
Manages the reinvestment of bond yields and buyback mechanisms.

#### Key Features
- Yield reinvestment
- Bond buyback
- Yield optimization strategies

#### Roles
- DEFAULT_ADMIN_ROLE: Can grant/revoke roles
- MANAGER_ROLE: Can set reinvestment parameters and execute reinvestments
- STRATEGY_MANAGER_ROLE: Can set and execute yield optimization strategies

### MannLiContingencyReserve
Manages the contingency reserve for risk mitigation.

#### Key Features
- Reserve funding
- Emergency mode
- Withdrawal limits
- Rate limiting

#### Roles
- DEFAULT_ADMIN_ROLE: Can grant/revoke roles and set withdrawal limits
- RISK_MANAGER_ROLE: Can manage emergency mode and withdraw emergency funds

## Security Considerations
- Rate limiting for sensitive operations
- Role-based access control
- Pausable functionality
- Reentrancy protection
- Minimum thresholds and maximum limits

## Integration Guide
See the [Integration Guide](./INTEGRATION.md) for details on how to integrate with the Mann Li Method contracts.
