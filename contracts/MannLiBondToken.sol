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
    
    struct BondParams {
        uint256 issueDate;
        uint256 maturityDate;
        uint256 initialRate;    // Initial coupon rate (10%)
        uint256 stepDownRate;   // Reduced rate after 5 years (7.75%)
        uint256 stepDownDate;   // Date when rate steps down
        bool maturityClaimed;   // Whether the bond has been redeemed at maturity
    }

    mapping(address => BondParams) public bondHolders;
    mapping(address => bool) public transferRestricted;
    
    uint256 public totalBondsIssued;
    uint256 public constant RATE_DENOMINATOR = 10000; // For handling percentages
    uint256 public constant TRANSFER_LOCKUP_PERIOD = 30 days;

    event BondIssued(address indexed holder, uint256 amount, uint256 issueDate, uint256 maturityDate);
    event CouponPaid(address indexed holder, uint256 amount, uint256 rate);
    event BondMaturityClaimed(address indexed holder, uint256 amount, uint256 maturityDate);
    event BondRedeemed(address indexed holder, uint256 amount, string reason);
    event TransferRestrictionSet(address indexed holder, bool restricted);

    constructor() ERC20("Mann Li Bond", "MLB") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
    }

    function issueBond(address to, uint256 amount) 
        external 
        onlyRole(ISSUER_ROLE) 
        whenNotPaused 
    {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");

        BondParams memory params = BondParams({
            issueDate: block.timestamp,
            maturityDate: block.timestamp + 3650 days, // 10 years
            initialRate: 1000,                         // 10.00%
            stepDownRate: 775,                         // 7.75%
            stepDownDate: block.timestamp + 1825 days, // 5 years
            maturityClaimed: false
        });

        bondHolders[to] = params;
        totalBondsIssued += amount;
        _mint(to, amount);

        emit BondIssued(to, amount, block.timestamp, params.maturityDate);
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
        
        params.maturityClaimed = true;
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
}