# Mann Li Method - Integration Guide

## Overview
This guide provides instructions for integrating with the Mann Li Method smart contracts from frontend applications.

## Contract ABIs
The contract ABIs are available in the `out` directory after compilation:
- `out/MannLiBondToken.sol/MannLiBondToken.json`
- `out/MannLiReinvestment.sol/MannLiReinvestment.json`
- `out/MannLiContingencyReserve.sol/MannLiContingencyReserve.json`

## TypeScript Types
TypeScript types for the contracts can be generated using TypeChain:
```bash
npm install --save-dev typechain @typechain/ethers-v5
npx typechain --target=ethers-v5 'out/**/*.json'
```

## Key Integration Points

### Bond Issuance
```typescript
// Example: Issue a bond
const bondToken = new ethers.Contract(bondTokenAddress, bondTokenABI, signer);
const tx = await bondToken.issueBond(holderAddress, ethers.utils.parseEther("1000"));
await tx.wait();
```

### Bond Series Management
```typescript
// Example: Create a new bond series
const tx = await bondToken.createBondSeries(
  "Series B",
  1200, // 12.00% initial rate
  900,  // 9.00% step-down rate
  3650, // 10 years maturity
  1825  // 5 years step-down
);
await tx.wait();
```

### Coupon Payments
```typescript
// Example: Pay coupon to a holder
const tx = await bondToken.payCoupon(holderAddress);
await tx.wait();
```

### Maturity Claiming
```typescript
// Example: Claim maturity (by bondholder)
const tx = await bondToken.claimMaturity();
await tx.wait();
```

### Early Redemption
```typescript
// Example: Redeem bonds early (by bondholder)
const tx = await bondToken.redeemEarly(ethers.utils.parseEther("500"));
await tx.wait();
```

### Rate Adjustment
```typescript
// Example: Adjust rates for a bond series
const tx = await bondToken.adjustSeriesRates(
  1, // Series ID
  1100, // 11.00% new initial rate
  800   // 8.00% new step-down rate
);
await tx.wait();
```

### Reinvestment
```typescript
// Example: Reinvest yield
const reinvestment = new ethers.Contract(reinvestmentAddress, reinvestmentABI, signer);
const tx = await reinvestment.reinvestYield();
await tx.wait();
```

### Contingency Reserve
```typescript
// Example: Fund the reserve
const reserve = new ethers.Contract(reserveAddress, reserveABI, signer);
const tx = await reserve.fundReserve({ value: ethers.utils.parseEther("10") });
await tx.wait();
```

## Event Monitoring
Monitor contract events to track bond issuance, coupon payments, and other activities:

```typescript
// Example: Monitor bond issuance events
bondToken.on("BondIssued", (holder, amount, issueDate, maturityDate, seriesId) => {
  console.log(`Bond issued to ${holder} for ${ethers.utils.formatEther(amount)} tokens`);
});

// Example: Monitor coupon payments
bondToken.on("CouponPaid", (holder, amount, rate) => {
  console.log(`Coupon paid to ${holder} for ${ethers.utils.formatEther(amount)} tokens at rate ${rate/100}%`);
});

// Example: Monitor early redemptions
bondToken.on("BondRedeemedEarly", (holder, amount, redemptionAmount, penalty) => {
  console.log(`Bond redeemed early by ${holder} for ${ethers.utils.formatEther(amount)} tokens`);
  console.log(`Redemption amount: ${ethers.utils.formatEther(redemptionAmount)}, Penalty: ${ethers.utils.formatEther(penalty)}`);
});

// Example: Monitor rate adjustments
bondToken.on("SeriesRatesAdjusted", (seriesId, oldInitialRate, newInitialRate, oldStepDownRate, newStepDownRate) => {
  console.log(`Rates adjusted for series ${seriesId}`);
  console.log(`Initial rate: ${oldInitialRate/100}% -> ${newInitialRate/100}%`);
  console.log(`Step-down rate: ${oldStepDownRate/100}% -> ${newStepDownRate/100}%`);
});
```

## Error Handling
Handle common errors:
- "Sender is restricted" - Transfer restrictions are in place
- "Transfer locked during initial period" - Bond is in lockup period
- "Bond not matured" - Attempting to claim maturity before maturity date
- "Rate limit: Too many actions" - Rate limiting is in effect
- "Invalid series ID" - The specified bond series does not exist
- "Invalid amount" - The amount specified is zero or negative
- "Insufficient balance" - The account does not have enough tokens
- "No bonds held" - The account does not hold any bonds
- "Maturity already claimed" - The bond maturity has already been claimed
