// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MannLiBondToken
 * @dev Implementation of the Mann Li Method Bond Token with step-down rate model
 */
contract MannLiBondToken is ERC20, Pausable, AccessControl {
    // Custom errors for gas optimization
    error InvalidInitialRate(uint256 rate);
    error InvalidStepDownRate(uint256 rate);
    error InvalidMaturityPeriod(uint256 period);
    error InvalidStepDownPeriod(uint256 period);
    error InvalidAddress();
    error InvalidAmount();
    error BondSeriesNotActive(uint256 seriesId);
    error NoBondsHeld();
    error BondNotMatured();
    error MaturityAlreadyClaimed();
    error InsufficientBalance(uint256 requested, uint256 available);
    error SenderRestricted();
    error RecipientRestricted();
    error TransferLocked(uint256 unlockTime);
    error InvalidSeriesId(uint256 seriesId);
    error RateLimitExceeded(uint256 nextAllowedTime);
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant RATE_MANAGER_ROLE = keccak256("RATE_MANAGER_ROLE");
    
    struct BondParams {
        uint256 issueDate;
        uint256 maturityDate;
        uint256 initialRate;    // Initial coupon rate (10%)
        uint256 stepDownRate;   // Reduced rate after 5 years (7.75%)
        uint256 stepDownDate;   // Date when rate steps down
        bool maturityClaimed;   // Whether the bond has been redeemed at maturity
        uint256 seriesId;       // Bond series identifier
    }
    
    // Bond series support
    struct BondSeries {
        string name;
        uint256 initialRate;
        uint256 stepDownRate;
        uint256 maturityPeriod; // In days
        uint256 stepDownPeriod; // In days
        bool active;
    }

    mapping(address => BondParams) public bondHolders;
    mapping(address => bool) public transferRestricted;
    mapping(uint256 => BondSeries) public bondSeries;
    mapping(address => uint256) public lastActionTime; // For rate limiting
    
    uint256 public totalBondsIssued;
    uint256 public nextSeriesId = 1;
    uint256 public constant RATE_DENOMINATOR = 10000; // For handling percentages
    uint256 public constant TRANSFER_LOCKUP_PERIOD = 30 days;

    event BondIssued(address indexed holder, uint256 amount, uint256 issueDate, uint256 maturityDate, uint256 seriesId);
    event CouponPaid(address indexed holder, uint256 amount, uint256 rate);
    event BondMaturityClaimed(address indexed holder, uint256 amount, uint256 maturityDate);
    event BondRedeemed(address indexed holder, uint256 amount, string reason);
    event BondRedeemedEarly(address indexed holder, uint256 amount, uint256 redemptionAmount, uint256 penalty);
    event TransferRestrictionSet(address indexed holder, bool restricted);
    event BondSeriesCreated(uint256 indexed seriesId, string name, uint256 initialRate, uint256 stepDownRate);
    event BondSeriesUpdated(uint256 indexed seriesId, bool active);
    event SeriesRatesAdjusted(uint256 indexed seriesId, uint256 oldInitialRate, uint256 newInitialRate, uint256 oldStepDownRate, uint256 newStepDownRate);

    modifier rateLimited() {
        if (block.timestamp < lastActionTime[msg.sender] + 1 hours)
            revert RateLimitExceeded(lastActionTime[msg.sender] + 1 hours);
        lastActionTime[msg.sender] = block.timestamp;
        _;
    }

    constructor() ERC20("Mann Li Bond", "MLB") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        _grantRole(RATE_MANAGER_ROLE, msg.sender);
        
        // Create default bond series
        _createBondSeries(
            "Series A",
            1000,   // 10.00% initial rate
            775,    // 7.75% step-down rate
            3650,   // 10 years maturity
            1825    // 5 years step-down
        );
    }
    
    function createBondSeries(
        string calldata name,
        uint256 initialRate,
        uint256 stepDownRate,
        uint256 maturityPeriod,
        uint256 stepDownPeriod
    ) external onlyRole(RATE_MANAGER_ROLE) returns (uint256) {
        return _createBondSeries(name, initialRate, stepDownRate, maturityPeriod, stepDownPeriod);
    }
    
    function _createBondSeries(
        string memory name,
        uint256 initialRate,
        uint256 stepDownRate,
        uint256 maturityPeriod,
        uint256 stepDownPeriod
    ) internal returns (uint256) {
        if (initialRate == 0 || initialRate > 2000) revert InvalidInitialRate(initialRate);
        if (stepDownRate == 0 || stepDownRate > initialRate) revert InvalidStepDownRate(stepDownRate);
        if (maturityPeriod == 0) revert InvalidMaturityPeriod(maturityPeriod);
        if (stepDownPeriod == 0 || stepDownPeriod >= maturityPeriod) revert InvalidStepDownPeriod(stepDownPeriod);
        
        uint256 seriesId = nextSeriesId++;
        
        bondSeries[seriesId] = BondSeries({
            name: name,
            initialRate: initialRate,
            stepDownRate: stepDownRate,
            maturityPeriod: maturityPeriod * 1 days,
            stepDownPeriod: stepDownPeriod * 1 days,
            active: true
        });
        
        emit BondSeriesCreated(seriesId, name, initialRate, stepDownRate);
        
        return seriesId;
    }

    function issueBond(address to, uint256 amount) 
        external 
        onlyRole(ISSUER_ROLE) 
        whenNotPaused 
    {
        // Use default series (1)
        issueBondFromSeries(to, amount, 1);
    }
    
    function issueBondFromSeries(address to, uint256 amount, uint256 seriesId)
        public
        onlyRole(ISSUER_ROLE)
        whenNotPaused
    {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (!bondSeries[seriesId].active) revert BondSeriesNotActive(seriesId);
        
        BondSeries memory series = bondSeries[seriesId];
        
        BondParams memory params = BondParams({
            issueDate: block.timestamp,
            maturityDate: block.timestamp + series.maturityPeriod,
            initialRate: series.initialRate,
            stepDownRate: series.stepDownRate,
            stepDownDate: block.timestamp + series.stepDownPeriod,
            maturityClaimed: false,
            seriesId: seriesId
        });

        bondHolders[to] = params;
        totalBondsIssued += amount;
        _mint(to, amount);

        emit BondIssued(to, amount, block.timestamp, params.maturityDate, seriesId);
    }

    function getCurrentRate(address holder) public view returns (uint256) {
        BondParams memory params = bondHolders[holder];
        if (params.issueDate == 0 || params.maturityClaimed) return 0;
        
        if (block.timestamp < params.stepDownDate) {
            return params.initialRate;
        }
        return params.stepDownRate;
    }

    function payCoupon(address holder) 
        external 
        onlyRole(ISSUER_ROLE) 
        whenNotPaused 
        returns (uint256)
    {
        if (balanceOf(holder) == 0) revert NoBondsHeld();
        
        uint256 rate = getCurrentRate(holder);
        uint256 amount = (balanceOf(holder) * rate) / RATE_DENOMINATOR;
        
        _mint(holder, amount); // Mint coupon payment
        emit CouponPaid(holder, amount, rate);
        
        return amount;
    }

    function claimMaturity() external whenNotPaused {
        BondParams storage params = bondHolders[msg.sender];
        if (params.issueDate == 0) revert NoBondsHeld();
        if (block.timestamp < params.maturityDate) revert BondNotMatured();
        if (params.maturityClaimed) revert MaturityAlreadyClaimed();
        
        uint256 balance = balanceOf(msg.sender);
        if (balance == 0) revert NoBondsHeld();
        
        // Transfer principal amount back to the holder
        params.maturityClaimed = true;
        
        // Mint additional tokens as final payment (principal remains intact)
        uint256 finalPayment = (balance * 500) / RATE_DENOMINATOR; // 5% final bonus
        _mint(msg.sender, finalPayment);
        
        emit BondMaturityClaimed(msg.sender, balance, params.maturityDate);
    }

    function redeem(address holder, uint256 amount, string calldata reason) 
        external 
        onlyRole(ISSUER_ROLE) 
        whenNotPaused 
    {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf(holder) < amount) revert InsufficientBalance(amount, balanceOf(holder));
        
        _burn(holder, amount);
        emit BondRedeemed(holder, amount, reason);
    }

    function setTransferRestriction(address holder, bool restricted) 
        external 
        onlyRole(ISSUER_ROLE) 
    {
        transferRestricted[holder] = restricted;
        emit TransferRestrictionSet(holder, restricted);
    }
    
    function setBondSeriesStatus(uint256 seriesId, bool active)
        external
        onlyRole(RATE_MANAGER_ROLE)
    {
        if (seriesId == 0 || seriesId >= nextSeriesId) revert InvalidSeriesId(seriesId);
        bondSeries[seriesId].active = active;
        emit BondSeriesUpdated(seriesId, active);
    }
    
    function getBondSeriesInfo(uint256 seriesId) 
        external 
        view 
        returns (
            string memory name,
            uint256 initialRate,
            uint256 stepDownRate,
            uint256 maturityPeriod,
            uint256 stepDownPeriod,
            bool active
        ) 
    {
        if (seriesId == 0 || seriesId >= nextSeriesId) revert InvalidSeriesId(seriesId);
        BondSeries memory series = bondSeries[seriesId];
        
        return (
            series.name,
            series.initialRate,
            series.stepDownRate,
            series.maturityPeriod / 1 days,
            series.stepDownPeriod / 1 days,
            series.active
        );
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) whenNotPaused {
        // Check transfer restrictions
        if (from != address(0) && to != address(0)) { // Exclude minting and burning
            if (transferRestricted[from]) revert SenderRestricted();
            if (transferRestricted[to]) revert RecipientRestricted();
            
            // Check lockup period for sender
            BondParams memory params = bondHolders[from];
            if (block.timestamp < params.issueDate + TRANSFER_LOCKUP_PERIOD) 
                revert TransferLocked(params.issueDate + TRANSFER_LOCKUP_PERIOD);
        }
        super._update(from, to, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function adjustSeriesRates(
        uint256 seriesId,
        uint256 newInitialRate,
        uint256 newStepDownRate
    ) 
        external 
        onlyRole(RATE_MANAGER_ROLE)
        rateLimited 
    {
        if (seriesId == 0 || seriesId >= nextSeriesId) revert InvalidSeriesId(seriesId);
        if (newInitialRate == 0 || newInitialRate > 2000) revert InvalidInitialRate(newInitialRate);
        if (newStepDownRate == 0 || newStepDownRate > newInitialRate) revert InvalidStepDownRate(newStepDownRate);
        
        BondSeries storage series = bondSeries[seriesId];
        
        // Store old rates for event
        uint256 oldInitialRate = series.initialRate;
        uint256 oldStepDownRate = series.stepDownRate;
        
        // Update rates
        series.initialRate = newInitialRate;
        series.stepDownRate = newStepDownRate;
        
        emit SeriesRatesAdjusted(seriesId, oldInitialRate, newInitialRate, oldStepDownRate, newStepDownRate);
    }
    
    function redeemEarly(uint256 amount) 
        external 
        whenNotPaused 
    {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance(amount, balanceOf(msg.sender));
        
        BondParams storage params = bondHolders[msg.sender];
        if (params.issueDate == 0) revert NoBondsHeld();
        if (params.maturityClaimed) revert MaturityAlreadyClaimed();
        
        // Calculate early redemption penalty (10% of amount)
        uint256 penalty = (amount * 1000) / RATE_DENOMINATOR;
        uint256 redemptionAmount = amount - penalty;
        
        // Burn the full amount but only return the redemption amount
        _burn(msg.sender, amount);
        
        emit BondRedeemedEarly(msg.sender, amount, redemptionAmount, penalty);
    }
}
