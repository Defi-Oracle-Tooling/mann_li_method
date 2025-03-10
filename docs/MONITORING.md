# Mann Li Method - Monitoring Guide

## Overview
This guide provides instructions for monitoring the Mann Li Method smart contracts using event logs.

## Key Events to Monitor

### MannLiBondToken Events
- **BondIssued**: Triggered when a new bond is issued
- **CouponPaid**: Triggered when a coupon payment is made
- **BondMaturityClaimed**: Triggered when a bond reaches maturity and is claimed
- **BondRedeemed**: Triggered when a bond is redeemed by the issuer
- **BondRedeemedEarly**: Triggered when a bond is redeemed early by the holder
- **TransferRestrictionSet**: Triggered when transfer restrictions are set
- **BondSeriesCreated**: Triggered when a new bond series is created
- **BondSeriesUpdated**: Triggered when a bond series is updated
- **SeriesRatesAdjusted**: Triggered when bond series rates are adjusted

### MannLiReinvestment Events
- **ReinvestmentRateUpdated**: Triggered when the reinvestment rate is updated
- **YieldReinvested**: Triggered when yield is reinvested
- **BuybackExecuted**: Triggered when a bond buyback is executed
- **BuybackParamsUpdated**: Triggered when buyback parameters are updated
- **ReinvestmentFailed**: Triggered when a reinvestment operation fails
- **EmergencyWithdrawal**: Triggered when an emergency withdrawal is made
- **ReinvestmentStrategyUpdated**: Triggered when the reinvestment strategy is updated
- **YieldOptimizationExecuted**: Triggered when yield optimization is executed

### MannLiContingencyReserve Events
- **ReserveFunded**: Triggered when the reserve is funded
- **EmergencyWithdrawal**: Triggered when an emergency withdrawal is made
- **EmergencyModeUpdated**: Triggered when emergency mode is updated
- **WithdrawalLimitsUpdated**: Triggered when withdrawal limits are updated
- **RateLimitExceeded**: Triggered when rate limits are exceeded

## Monitoring Setup

### Using The Graph
1. Create a subgraph for the Mann Li Method contracts
2. Define schema for all events
3. Deploy the subgraph
4. Query the subgraph for event data

### Using Web3.js/Ethers.js
```javascript
const { ethers } = require("ethers");
const provider = new ethers.providers.WebSocketProvider("wss://mainnet.infura.io/ws/v3/YOUR_INFURA_KEY");

const bondTokenABI = [...]; // ABI with events
const bondTokenAddress = "0x...";
const bondToken = new ethers.Contract(bondTokenAddress, bondTokenABI, provider);

// Monitor bond issuance
bondToken.on("BondIssued", (holder, amount, issueDate, maturityDate, seriesId) => {
  console.log(`Bond issued to ${holder} for ${ethers.utils.formatEther(amount)} tokens`);
  console.log(`Series ID: ${seriesId}, Maturity: ${new Date(maturityDate * 1000).toISOString()}`);
});

// Monitor coupon payments
bondToken.on("CouponPaid", (holder, amount, rate) => {
  console.log(`Coupon paid to ${holder} for ${ethers.utils.formatEther(amount)} tokens at rate ${rate/100}%`);
});

// Monitor maturity claims
bondToken.on("BondMaturityClaimed", (holder, amount, maturityDate) => {
  console.log(`Bond maturity claimed by ${holder} for ${ethers.utils.formatEther(amount)} tokens`);
});
```

## Alerting
Set up alerts for critical events:
- Emergency mode activation
- Large withdrawals from contingency reserve
- Failed reinvestment operations
- Rate limit exceeded events

## Dashboard
Create a dashboard to visualize:
- Total bonds issued
- Active bond series
- Coupon payments over time
- Reinvestment performance
- Contingency reserve status
