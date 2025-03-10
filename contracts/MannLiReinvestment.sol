// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MannLiBondToken.sol";

/**
 * @title MannLiReinvestment
 * @dev Manages reinvestment of bond yields and buyback mechanisms
 */
contract MannLiReinvestment is AccessControl, ReentrancyGuard {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    MannLiBondToken public bondToken;
    
    struct ReinvestmentPool {
        uint256 totalFunds;
        uint256 reinvestmentRate;     // 20-50% of coupon payments
        uint256 lastReinvestmentTime;
        uint256 totalReinvested;      // Track total amount reinvested
        uint256 totalBuybacks;        // Track total buybacks
    }

    struct BuybackParams {
        uint256 minimumAmount;        // Minimum amount for buyback
        uint256 maximumAmount;        // Maximum amount for buyback
        uint256 discountRate;         // Discount rate for buybacks (in basis points)
        uint256 cooldownPeriod;       // Time between buybacks for same holder
    }

    ReinvestmentPool public pool;
    BuybackParams public buybackParams;
    
    // Track last buyback time for each holder
    mapping(address => uint256) public lastBuybackTime;
    // Track total buybacks per holder
    mapping(address => uint256) public holderBuybacks;
    
    event ReinvestmentRateUpdated(uint256 oldRate, uint256 newRate);
    event YieldReinvested(uint256 amount, uint256 timestamp, uint256 newTotalReinvested);
    event BuybackExecuted(
        address indexed holder,
        uint256 bondAmount,
        uint256 ethAmount,
        uint256 discountApplied
    );
    event BuybackParamsUpdated(
        uint256 minimumAmount,
        uint256 maximumAmount,
        uint256 discountRate,
        uint256 cooldownPeriod
    );
    event ReinvestmentFailed(string reason, uint256 amount);
    event EmergencyWithdrawal(address indexed admin, uint256 amount);

    constructor(address _bondToken) {
        bondToken = MannLiBondToken(_bondToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        
        pool = ReinvestmentPool({
            totalFunds: 0,
            reinvestmentRate: 3000,    // 30% default reinvestment rate
            lastReinvestmentTime: block.timestamp,
            totalReinvested: 0,
            totalBuybacks: 0
        });

        buybackParams = BuybackParams({
            minimumAmount: 1 ether,    // 1 bond token minimum
            maximumAmount: 100 ether,  // 100 bond tokens maximum
            discountRate: 500,         // 5% discount
            cooldownPeriod: 30 days    // 30 days between buybacks
        });
    }

    function setReinvestmentRate(uint256 newRate) external onlyRole(MANAGER_ROLE) {
        require(newRate >= 2000 && newRate <= 5000, "Rate must be between 20-50%");
        uint256 oldRate = pool.reinvestmentRate;
        pool.reinvestmentRate = newRate;
        emit ReinvestmentRateUpdated(oldRate, newRate);
    }

    function setBuybackParams(
        uint256 _minimumAmount,
        uint256 _maximumAmount,
        uint256 _discountRate,
        uint256 _cooldownPeriod
    ) external onlyRole(MANAGER_ROLE) {
        require(_minimumAmount > 0, "Invalid minimum amount");
        require(_maximumAmount >= _minimumAmount, "Invalid maximum amount");
        require(_discountRate <= 2000, "Discount too high"); // Max 20% discount
        require(_cooldownPeriod > 0, "Invalid cooldown period");

        buybackParams = BuybackParams({
            minimumAmount: _minimumAmount,
            maximumAmount: _maximumAmount,
            discountRate: _discountRate,
            cooldownPeriod: _cooldownPeriod
        });

        emit BuybackParamsUpdated(
            _minimumAmount,
            _maximumAmount,
            _discountRate,
            _cooldownPeriod
        );
    }

    function reinvestYield() external nonReentrant onlyRole(MANAGER_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to reinvest");
        
        uint256 reinvestAmount = (balance * pool.reinvestmentRate) / 10000;
        require(reinvestAmount > 0, "Reinvestment amount too small");

        try this.executeReinvestment(reinvestAmount) {
            pool.totalFunds += reinvestAmount;
            pool.totalReinvested += reinvestAmount;
            pool.lastReinvestmentTime = block.timestamp;
            
            emit YieldReinvested(reinvestAmount, block.timestamp, pool.totalReinvested);
        } catch Error(string memory reason) {
            emit ReinvestmentFailed(reason, reinvestAmount);
        }
    }

    function executeReinvestment(uint256 amount) external {
        require(msg.sender == address(this), "Only internal calls");
        // Implementation of reinvestment strategy
        // This could involve various DeFi protocols or yield farming strategies
    }

    function executeBuyback(address holder, uint256 amount) 
        external 
        nonReentrant 
        onlyRole(MANAGER_ROLE) 
    {
        require(amount >= buybackParams.minimumAmount, "Amount below minimum");
        require(amount <= buybackParams.maximumAmount, "Amount above maximum");
        require(
            block.timestamp >= lastBuybackTime[holder] + buybackParams.cooldownPeriod,
            "Cooldown period not elapsed"
        );
        require(bondToken.balanceOf(holder) >= amount, "Insufficient bonds");
        require(pool.totalFunds >= amount, "Insufficient pool funds");

        uint256 buybackPrice = calculateBuybackPrice(amount);
        require(buybackPrice <= pool.totalFunds, "Insufficient funds for buyback");

        lastBuybackTime[holder] = block.timestamp;
        holderBuybacks[holder] += amount;
        pool.totalFunds -= buybackPrice;
        pool.totalBuybacks += amount;

        // Transfer bonds from holder to this contract
        require(
            bondToken.transferFrom(holder, address(this), amount),
            "Bond transfer failed"
        );
        
        // Burn the bought back bonds
        bondToken.redeem(address(this), amount, "Buyback and burn");
        
        // Transfer ETH to holder
        (bool success, ) = holder.call{value: buybackPrice}("");
        require(success, "ETH transfer failed");

        emit BuybackExecuted(
            holder,
            amount,
            buybackPrice,
            buybackParams.discountRate
        );
    }

    function calculateBuybackPrice(uint256 amount) public view returns (uint256) {
        // Apply discount to face value
        uint256 discount = (amount * buybackParams.discountRate) / 10000;
        return amount - discount;
    }

    function getReinvestmentStats() external view returns (
        uint256 totalReinvested,
        uint256 totalBuybacks,
        uint256 currentFunds,
        uint256 reinvestmentRate
    ) {
        return (
            pool.totalReinvested,
            pool.totalBuybacks,
            pool.totalFunds,
            pool.reinvestmentRate
        );
    }

    // Emergency withdrawal function
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Withdrawal failed");
        emit EmergencyWithdrawal(msg.sender, balance);
    }

    receive() external payable {}
}