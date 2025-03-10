// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MannLiBondToken
 * @dev Implementation of the Mann Li Method Bond Token with step-down rate model
 */
contract MannLiBondToken is ERC20Pausable, AccessControl {
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
        require(
            block.timestamp >= lastActionTime[msg.sender] + 1 hours,
            "Rate limit: Too many actions"
        );
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
        require(initialRate > 0 && initialRate <= 2000, "Invalid initial rate"); // Max 20%
        require(stepDownRate > 0 && stepDownRate <= initialRate, "Invalid step-down rate");
        require(maturityPeriod > 0, "Invalid maturity period");
        require(stepDownPeriod > 0 && stepDownPeriod < maturityPeriod, "Invalid step-down period");
        
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
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(bondSeries[seriesId].active, "Bond series not active");
        
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
        require(balanceOf(holder) > 0, "No bonds held");
        
        uint256 rate = getCurrentRate(holder);
        uint256 amount = (balanceOf(holder) * rate) / RATE_DENOMINATOR;
        
        _mint(holder, amount); // Mint coupon payment
        emit CouponPaid(holder, amount, rate);
        
        return amount;
    }

    function claimMaturity() external whenNotPaused {
        BondParams storage params = bondHolders[msg.sender];
        require(params.issueDate > 0, "No bonds held");
        require(block.timestamp >= params.maturityDate, "Bond not matured");
        require(!params.maturityClaimed, "Maturity already claimed");
        
        uint256 balance = balanceOf(msg.sender);
        require(balance > 0, "No bonds to claim");
        
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
        require(amount > 0, "Invalid amount");
        require(balanceOf(holder) >= amount, "Insufficient balance");
        
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
        require(seriesId > 0 && seriesId < nextSeriesId, "Invalid series ID");
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
        require(seriesId > 0 && seriesId < nextSeriesId, "Invalid series ID");
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
    ) internal virtual override {
        // Check transfer restrictions
        if (from != address(0) && to != address(0)) { // Exclude minting and burning
            require(!transferRestricted[from], "Sender is restricted");
            require(!transferRestricted[to], "Recipient is restricted");
            
            // Check lockup period for sender
            BondParams memory params = bondHolders[from];
            require(
                block.timestamp >= params.issueDate + TRANSFER_LOCKUP_PERIOD,
                "Transfer locked during initial period"
            );
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
        require(seriesId > 0 && seriesId < nextSeriesId, "Invalid series ID");
        require(newInitialRate > 0 && newInitialRate <= 2000, "Invalid initial rate"); // Max 20%
        require(newStepDownRate > 0 && newStepDownRate <= newInitialRate, "Invalid step-down rate");
        
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
        require(amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        BondParams storage params = bondHolders[msg.sender];
        require(params.issueDate > 0, "No bonds held");
        require(!params.maturityClaimed, "Maturity already claimed");
        
        // Calculate early redemption penalty (10% of amount)
        uint256 penalty = (amount * 1000) / RATE_DENOMINATOR;
        uint256 redemptionAmount = amount - penalty;
        
        // Burn the full amount but only return the redemption amount
        _burn(msg.sender, amount);
        
        emit BondRedeemedEarly(msg.sender, amount, redemptionAmount, penalty);
    }
}
