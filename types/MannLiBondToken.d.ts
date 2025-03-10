export interface BondParams {
  issueDate: number;
  maturityDate: number;
  initialRate: number;
  stepDownRate: number;
  stepDownDate: number;
  maturityClaimed: boolean;
  seriesId: number;
}

export interface BondSeries {
  name: string;
  initialRate: number;
  stepDownRate: number;
  maturityPeriod: number;
  stepDownPeriod: number;
  active: boolean;
}

export interface MannLiBondToken {
  // Read functions
  name(): Promise<string>;
  symbol(): Promise<string>;
  totalSupply(): Promise<BigNumber>;
  balanceOf(account: string): Promise<BigNumber>;
  bondHolders(holder: string): Promise<BondParams>;
  bondSeries(seriesId: number): Promise<BondSeries>;
  getCurrentRate(holder: string): Promise<BigNumber>;
  getBondSeriesInfo(seriesId: number): Promise<[string, BigNumber, BigNumber, BigNumber, BigNumber, boolean]>;
  lastActionTime(account: string): Promise<BigNumber>;
  
  // Write functions
  issueBond(to: string, amount: BigNumber): Promise<TransactionResponse>;
  issueBondFromSeries(to: string, amount: BigNumber, seriesId: number): Promise<TransactionResponse>;
  payCoupon(holder: string): Promise<TransactionResponse>;
  claimMaturity(): Promise<TransactionResponse>;
  redeem(holder: string, amount: BigNumber, reason: string): Promise<TransactionResponse>;
  redeemEarly(amount: BigNumber): Promise<TransactionResponse>;
  setTransferRestriction(holder: string, restricted: boolean): Promise<TransactionResponse>;
  createBondSeries(name: string, initialRate: number, stepDownRate: number, maturityPeriod: number, stepDownPeriod: number): Promise<TransactionResponse>;
  setBondSeriesStatus(seriesId: number, active: boolean): Promise<TransactionResponse>;
  adjustSeriesRates(seriesId: number, newInitialRate: number, newStepDownRate: number): Promise<TransactionResponse>;
  pause(): Promise<TransactionResponse>;
  unpause(): Promise<TransactionResponse>;
  
  // Events
  filters: {
    BondIssued(holder?: string, amount?: null, issueDate?: null, maturityDate?: null, seriesId?: number): EventFilter;
    CouponPaid(holder?: string, amount?: null, rate?: null): EventFilter;
    BondMaturityClaimed(holder?: string, amount?: null, maturityDate?: null): EventFilter;
    BondRedeemed(holder?: string, amount?: null, reason?: null): EventFilter;
    BondRedeemedEarly(holder?: string, amount?: null, redemptionAmount?: null, penalty?: null): EventFilter;
    TransferRestrictionSet(holder?: string, restricted?: null): EventFilter;
    BondSeriesCreated(seriesId?: number, name?: null, initialRate?: null, stepDownRate?: null): EventFilter;
    BondSeriesUpdated(seriesId?: number, active?: null): EventFilter;
    SeriesRatesAdjusted(seriesId?: number, oldInitialRate?: null, newInitialRate?: null, oldStepDownRate?: null, newStepDownRate?: null): EventFilter;
    Transfer(from?: string, to?: string, value?: null): EventFilter;
    Approval(owner?: string, spender?: string, value?: null): EventFilter;
    Paused(): EventFilter;
    Unpaused(): EventFilter;
  }
}
