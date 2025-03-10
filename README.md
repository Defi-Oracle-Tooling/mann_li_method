# Mann Li Method Implementation

<div align="center">
  <img src="https://img.shields.io/badge/Solidity-0.8.20-blue.svg" alt="Solidity 0.8.20" />
  <img src="https://img.shields.io/badge/Foundry-Built%20With-orange.svg" alt="Built with Foundry" />
  <img src="https://img.shields.io/badge/OpenZeppelin-5.0.0-green.svg" alt="OpenZeppelin 5.0.0" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License: MIT" />
</div>

<div align="center">
  <img src="https://mermaid.ink/img/pako:eNp1kU9PwzAMxb_KyU6AhNRe0GlHOCGxGya4pU2aek1TJQ5CU_fd6dotnTRxip_9_PxsT0JbjaIUuem61hinEThk5qTREYfK5yhfmOdgaU0yMz9014DSv94_uRhKtDFx-wFHdASlRQcYYTzhlMAEFEoUFslKZ4g7UogH1vbkS19L9i4DufAYTpbd3KAJYDTWUZtHje85SprUqK2LaV0k8tpjv0qRCccYmbad9qRDhWY9rCG1fBIVytly1F8JnV3MCjVaVOg40YnMDwlzpnzwkgYq0fMGpKsRdPMKl0lxuNQV18RD5UJKkdebzDmW3Cj6MztA5E_PaGPJttz7qv9cDfW8Kv77kOMDw4V4FA7c255-GQEPrlpcGdtehGnEZvYLL2h1jA" alt="Mann Li Method Architecture" />
</div>

<p align="center">
  <i>A comprehensive smart contract system for decentralized financial structuring</i>
</p>

## 📋 Overview

The Mann Li Method implements a blockchain-based financial structuring approach through a set of interconnected smart contracts. This system provides robust mechanisms for bond issuance, yield reinvestment, and risk mitigation on the Ethereum blockchain.

### Why Mann Li Method?

The Mann Li Method addresses key challenges in decentralized finance:

- **Yield Optimization**: Automatically reinvests a portion of yields for compound growth
- **Risk Management**: Built-in contingency reserves protect against market volatility
- **Flexible Bond Structures**: Supports multiple bond series with customizable parameters
- **Transparent Governance**: Role-based access control with clear separation of duties

## 🧩 Core Components

<table>
  <tr>
    <td align="center">
      <img src="https://img.shields.io/badge/Contract-MannLiBondToken-blue" alt="MannLiBondToken" /><br>
      ERC20-based bond token with step-down rate model and series support
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Contract-MannLiReinvestment-green" alt="MannLiReinvestment" /><br>
      Manages reinvestment of bond yields, buybacks, and yield optimization
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Contract-MannLiContingencyReserve-orange" alt="MannLiContingencyReserve" /><br>
      Handles contingency reserve for risk mitigation with multi-level emergency modes
    </td>
  </tr>
</table>

## 🔑 Key Features

<div align="center">
  <img src="https://mermaid.ink/img/pako:eNplkk1rwzAMhv-KMadCCcnWD3xbO8YOg91G2a2LbeJFtDG2MzpC_vs5TdIVdt4kv5If2StUzkmokK-NfpPQTxEwSJTpkPyBPgq0DroJx4iS69ETVuYnYaU9ozZ-B3v6AnCDFOGEsP-Ev-8LkvYsfLMZE6gaNKLnco9-eZvtflQttKt16WGYm-eMtjmLTVnohauc6p1q9UE5Mbmfbpp6Do8v-XisK6itOtk7nUL_JyqZvBuHfgELafG7c2Oz4PS6zaWY-3eMjFG7LKUx_ryxokKtvUeV2-z_4IcXierHEHwmpg3zhMgdnms72_Qb2PMnadnbIUNcrllnlJbVXbY1JelJ3eo8sl4pJWjlplQpWHrcUSJjO6mQ1xNJqJplQOkrVMz62YMZbahgQ2VPWmhfVbC9WKXeS_MGM0fach" alt="Mann Li Method Features" />
</div>

- **Bond Series Support**: Create multiple bond series with customizable parameters
- **Step-down Rate Model**: 10% initial, 7.75% after 5 years (configurable per series)
- **Maturity Claiming**: Bondholders can claim maturity with bonus payment
- **Automated Coupon Payments**: Regular interest distributions to bondholders
- **Yield Optimization Strategies**: Pluggable strategy system for maximizing returns
- **Reinvestment Pool**: Configurable rates (20-50%) for yield optimization
- **Emergency Contingency Reserve**: Multi-level risk mitigation system
- **Role-based Access Control**: Fine-grained permission management

## 🔄 Integration and Compatibility Analysis

The Mann Li Method creates an integrated financial ecosystem through three interdependent contracts working in concert:

### Contract Integration Flow

```mermaid
flowchart TD
    A[MannLiBondToken] -->|references| B[MannLiReinvestment]
    B -->|calls| C{Bond Actions}
    C -->|transferFrom| A
    C -->|redeem| A
    B -.->|financial relationship| D[MannLiContingencyReserve]
    D -->|risk mitigation| A
    E[Yield Optimization Strategies] -.->|pluggable| B
    
    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style D fill:#fb7,stroke:#333,stroke-width:2px
    style E fill:#bfb,stroke:#333,stroke-width:2px
```

### 1️⃣ MannLiBondToken ↔ MannLiReinvestment

The Reinvestment contract maintains a direct reference to the Bond Token:

```solidity
MannLiBondToken public bondToken;

constructor(address _bondToken) {
    bondToken = MannLiBondToken(_bondToken);
    // ...
}
```

- Reinvestment can call `transferFrom` and `redeem` functions on the Bond Token
- Bond buybacks involve transferring tokens from holders to the Reinvestment contract, then burning them
- Event emissions in both contracts create an audit trail across the system

### 2️⃣ MannLiReinvestment ↔ MannLiContingencyReserve

While not directly linked in code, these components maintain a financial relationship:

- Both contracts maintain separate ETH reserves through their `receive()` functions
- They're designed to balance financial stability through complementary mechanisms
- Emergency functions exist in both contracts with different authorization requirements

### 3️⃣ Role-Based Access Control

<div align="center">
  <img src="https://mermaid.ink/img/pako:eNptkstqwzAQRX9lmFULidukDy9atmnaRSGELrrsRpXGsYltGUkONMb_XtlO3JCZlTT33JnRY6WUkVCoXMnwXcMwDOAhka8aA7LdUaSdhCDD6mDpFVh6G4GkBlWT9zTIAezIUSPBqQAP68BBPsJhn9_ypjkl5OaqWnzPJlRooL5gPrpPUmc0vSC9sI8Wm6OpTGe27soy0SmZyRg-wtBWm8rKUNcKWxuo86a_Pjt4sNotYsfx4cDVnakmzDyiiGorLq5Sl0Ia1Tpdmt7qentEcZeIrD1ig7pWsaSrn3fVeHM_Cecx3DnZOPliUlKK8BioVCfnTx0puHuifkvB2R81IJYEbVQFhZwXEFf6UfqvQqxT_n-dQthTmFsohESPbd8JuOFIVbF5Bj1PvNQ" alt="Role-Based Access Control" />
</div>

All contracts implement OpenZeppelin's AccessControl with custom roles:

- `ISSUER_ROLE` - For bond token management
- `MANAGER_ROLE` - For reinvestment operations
- `STRATEGY_MANAGER_ROLE` - For yield optimization strategies
- `RISK_MANAGER_ROLE` - For contingency reserve handling
- `DEFAULT_ADMIN_ROLE` - Universal administrative privileges

## 🔒 System Security Features

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Pausability** | Emergency halt for critical functions | `whenNotPaused` modifier |
| **Reentrancy Protection** | Prevents reentrancy attacks | `ReentrancyGuard` inheritance |
| **Rate Limiting** | Prevents rapid state changes | Custom time-based checks |
| **Emergency Mechanisms** | Multi-level withdrawal systems | Role-based approvals |
| **Transfer Restrictions** | Prevents unauthorized transfers | Custom transfer hooks |

## 📦 External Dependencies

- **OpenZeppelin Contracts v5.0.0**
  - ERC20Pausable for token functionality
  - AccessControl for role-based permissions
  - ReentrancyGuard for security
  - Pausable for emergency halting

## 🚀 Deployment Considerations

Proper deployment order is critical for contract integration:

1. Deploy `MannLiBondToken` first
2. Deploy `MannLiReinvestment` with the bond token address
3. Deploy `MannLiContingencyReserve` with appropriate parameters
4. Configure roles across all contracts
5. Create initial bond series if needed

## 🏗️ Technical Architecture

<div align="center">
  <img src="https://mermaid.ink/img/pako:eNqNk01P5DAMhv9KlBMgIfULOHXggAQ7aFd7YbltkiZtnLpO0xGa0f53Ou100I6Y8anx4_f1RxJfhTGaRSnOtetHDacJOGTmT6MjDl_5HOUdPQNbaZKp-NUdDUr_64PsYmBpXFbD3Q4xOoLWogOMMJ5wSmACCiVaVCb1Nps0K0QfqOs_pK-12PkC5JXHYDwrt4NNAKM1Dlat5DEPviUoJaWm2rmYIuJsWQIp3b3eF3vwQNaUGu-oIvPJ7sBYEuWRTLFnrHrsLSeyVPgAel4lQm-m7qHyFqVvI1o24z35PdzRRELwtCEmjltDFBImv_r03KFy5kCnrRj5FzK8tn_SbmY6p-WjOeC5JGMKaDwxiyWij61mJRUaREVN2l6EDT2oe-yrxQqHWun_7Pmp3Fwp5EXACFa1T1QtKTOSRsunjc3jGjMtN7U8P5YvZ1o-ih5kOzvJCiEDJtW4kyUI3VwJOVcN9jbP0Sh7pv6fo_0DGPgRqw" alt="Technical Architecture" />
</div>

### MannLiBondToken

A specialized ERC20 token implementing a bond instrument with:

- Bond series/tranche support for multiple issuances
- 10-year maturity period (configurable per series)
- Step-down interest rate (configurable per series)
- Transfer restrictions and lockup periods
- Bond redemption and maturity claim functions

### MannLiReinvestment

Manages reinvestment strategies for bond yields:

- Configurable reinvestment rate (20-50%)
- Pluggable yield optimization strategies
- Bond buyback mechanism with discount rates
- Cooldown periods between buybacks for each holder
- Emergency fund withdrawal capability

### MannLiContingencyReserve

Provides risk mitigation through a reserve fund:

- Emergency mode with 3 levels of severity
- Threshold-based reserve requirements
- Daily and per-transaction withdrawal limits
- Rate-limiting for administrative actions

## 💻 Development

This project uses Foundry for development and testing.

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- Node.js >= 16
- npm or yarn

### Setup

```shell
# Clone the repository
git clone https://github.com/Defi-Oracle-Tooling/mann_li_method.git
cd mann_li_method

# Install dependencies
forge install
npm install

# Build the project
forge build
```

### Available Commands

<details>
<summary>View Commands</summary>

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
</details>

## 📁 Project Structure

```
contracts/          # Smart contracts
├─ MannLiBondToken.sol
├─ MannLiReinvestment.sol
└─ MannLiContingencyReserve.sol

test/              # Test files
├─ MannLiBondToken.t.sol
├─ MannLiReinvestment.t.sol
└─ MannLiContingencyReserve.t.sol

script/            # Deployment scripts
└─ Deploy.s.sol
```

## 📊 Use Cases

- **Institutional Bond Issuance**: Organizations can issue bonds with customizable parameters
- **Yield Optimization**: Automatically reinvest yields for compound growth
- **Risk Mitigation**: Built-in contingency reserves protect against market volatility
- **Secondary Market**: Bondholders can trade tokens after the initial lockup period

## 🔮 Future Roadmap

- Cross-chain compatibility for multi-chain bond issuance
- Integration with external DeFi protocols for enhanced yield strategies
- Governance framework for decentralized parameter updates
- Secondary market features for improved bond liquidity

## 📦 Submodule Integration

This repository can be integrated as a submodule in the SolaceNet mono-repository while maintaining standalone functionality.

### Adding as a Submodule

```shell
# Add the submodule to SolaceNet
git submodule add https://github.com/Defi-Oracle-Tooling/mann_li_method.git libs/mann_li_method

# Initialize and update the submodule
git submodule update --init --recursive

# Configure the submodule for SolaceNet integration
cd libs/mann_li_method
pnpm run submodule:setup
```

For detailed integration instructions, see [Submodule Integration Guide](docs/SUBMODULE_INTEGRATION.md).

## 📜 License

MIT
