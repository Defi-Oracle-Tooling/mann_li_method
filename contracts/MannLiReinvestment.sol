// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { MannLiBondToken } from "./MannLiBondToken.sol";

/**
 * @title MannLiReinvestment
 * @dev Manages reinvestment of bond yields and buyback mechanisms
 */
contract MannLiReinvestment is ReentrancyGuard, AccessControl, Pausable {
    // Custom errors for gas optimization
    error InvalidRate(uint256 rate);
    error InvalidMinimumAmount();
    error InvalidMaximumAmount(uint256 min, uint256 max);
    error InvalidDiscountRate(uint256 rate);
    error InvalidCooldownPeriod();
    error NoFundsToReinvest();
    error ReinvestmentAmountTooSmall();
    error AmountBelowMinimum(uint256 amount, uint256 minimum);
    error AmountAboveMaximum(uint256 amount, uint256 maximum);
    error CooldownPeriodNotElapsed(uint256 nextAllowedTime);
    error InsufficientBonds(uint256 requested, uint256 available);
    error InsufficientPoolFunds(uint256 requested, uint256 available);
    error BondTransferFailed();
    error EthTransferFailed();
    error OnlyInternalCalls();
    error NoStrategySet();
    error InvalidStrategyAddress();
    error InvalidAmount();
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant STRATEGY_MANAGER_ROLE = keccak256("STRATEGY_MANAGER_ROLE");
    
    MannLiBondToken public bondToken;
    
    // Strategy interface for yield optimization
    address public currentStrategy;
    
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
    event ReinvestmentStrategyUpdated(string strategyName, address strategyAddress);
    event YieldOptimizationExecuted(uint256 amount, uint256 newYield);

    constructor(address _bondToken) {
        bondToken = MannLiBondToken(_bondToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(STRATEGY_MANAGER_ROLE, msg.sender);
        
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
        if (newRate < 2000 || newRate > 5000) revert InvalidRate(newRate);
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
        if (_minimumAmount == 0) revert InvalidMinimumAmount();
        if (_maximumAmount < _minimumAmount) revert InvalidMaximumAmount(_minimumAmount, _maximumAmount);
        if (_discountRate > 2000) revert InvalidDiscountRate(_discountRate); // Max 20% discount
        if (_cooldownPeriod == 0) revert InvalidCooldownPeriod();

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
        if (balance == 0) revert NoFundsToReinvest();
        
        uint256 reinvestAmount = (balance * pool.reinvestmentRate) / 10000;
        if (reinvestAmount == 0) revert ReinvestmentAmountTooSmall();

        try this.executeReinvestment(reinvestAmount) {
            // Note: executeReinvestment already updates pool.totalFunds
            pool.totalReinvested += reinvestAmount;
            pool.lastReinvestmentTime = block.timestamp;
            
            emit YieldReinvested(reinvestAmount, block.timestamp, pool.totalReinvested);
        } catch Error(string memory reason) {
            emit ReinvestmentFailed(reason, reinvestAmount);
        }
    }

    function executeReinvestment(uint256 _amount) external {
        if (msg.sender != address(this)) revert OnlyInternalCalls();
        // Store the amount in the pool's totalFunds since this is
        // a placeholder for future DeFi integrations
        pool.totalFunds += _amount;
    }

    function executeBuyback(address holder, uint256 amount) 
        external 
        nonReentrant 
        onlyRole(MANAGER_ROLE) 
    {
        if (amount < buybackParams.minimumAmount) revert AmountBelowMinimum(amount, buybackParams.minimumAmount);
        if (amount > buybackParams.maximumAmount) revert AmountAboveMaximum(amount, buybackParams.maximumAmount);
        if (block.timestamp < lastBuybackTime[holder] + buybackParams.cooldownPeriod)
            revert CooldownPeriodNotElapsed(lastBuybackTime[holder] + buybackParams.cooldownPeriod);
        if (bondToken.balanceOf(holder) < amount) revert InsufficientBonds(amount, bondToken.balanceOf(holder));
        if (pool.totalFunds < amount) revert InsufficientPoolFunds(amount, pool.totalFunds);

        uint256 buybackPrice = calculateBuybackPrice(amount);
        if (buybackPrice > pool.totalFunds) revert InsufficientPoolFunds(buybackPrice, pool.totalFunds);

        lastBuybackTime[holder] = block.timestamp;
        holderBuybacks[holder] += amount;
        pool.totalFunds -= buybackPrice;
        pool.totalBuybacks += amount;

        // Transfer bonds from holder to this contract
        if (!bondToken.transferFrom(holder, address(this), amount))
            revert BondTransferFailed();
        
        // Burn the bought back bonds
        bondToken.redeem(address(this), amount, "Buyback and burn");
        
        // Transfer ETH to holder
        (bool success, ) = holder.call{value: buybackPrice}("");
        if (!success) revert EthTransferFailed();

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
        if (!success) revert EthTransferFailed();
        emit EmergencyWithdrawal(msg.sender, balance);
    }
    
    // Strategy management functions
    function setReinvestmentStrategy(address strategyAddress, string calldata strategyName) 
        external 
        onlyRole(STRATEGY_MANAGER_ROLE) 
    {
        if (strategyAddress == address(0)) revert InvalidStrategyAddress();
        currentStrategy = strategyAddress;
        emit ReinvestmentStrategyUpdated(strategyName, strategyAddress);
    }
    
    function optimizeYield(uint256 amount) 
        external 
        nonReentrant 
        onlyRole(STRATEGY_MANAGER_ROLE) 
        returns (uint256)
    {
        if (currentStrategy == address(0)) revert NoStrategySet();
        if (amount == 0 || amount > pool.totalFunds) revert InvalidAmount();
        
        // Placeholder for strategy execution
        // In a real implementation, this would call into the strategy contract
        uint256 newYield = amount + (amount * 5 / 100); // Simulate 5% yield
        pool.totalFunds = (pool.totalFunds - amount) + newYield;
        
        emit YieldOptimizationExecuted(amount, newYield);
        return newYield;
    }

    receive() external payable {}
}
