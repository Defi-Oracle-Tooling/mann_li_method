// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title MannLiContingencyReserve
 * @dev Manages the 20% contingency reserve allocation for risk mitigation
 */
contract MannLiContingencyReserve is ReentrancyGuard, AccessControl, Pausable {
    // Custom errors for gas optimization
    error NoFundsSent();
    error InvalidEmergencyLevel(uint256 level);
    error NotInEmergencyMode();
    error AlreadyInEmergencyMode();
    error ReservesBelowMinimumThreshold();
    error CooldownPeriodNotElapsed(uint256 nextAllowedTime);
    error AmountExceedsMaximum(uint256 amount, uint256 maximum);
    error WithdrawalBreachesMinimumThreshold(uint256 remaining, uint256 minimum);
    error DailyWithdrawalLimitExceeded(uint256 requested, uint256 remaining);
    error RateLimitError(uint256 nextAllowedTime);
    error TransferFailed();
    error InvalidMaxAmount();
    error DailyLimitTooLow(uint256 dailyLimit, uint256 maxAmount);
    error InvalidCooldownPeriod();
    error InvalidThreshold();
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    struct ReservePool {
        uint256 totalReserves;
        uint256 minimumThreshold;    // Minimum reserve requirement
        uint256 lastWithdrawalTime;
        bool emergencyMode;
        uint256 emergencyLevel;      // 1: Low, 2: Medium, 3: High
        uint256 totalWithdrawals;    // Track total withdrawals
    }

    struct WithdrawalLimit {
        uint256 maxAmount;           // Maximum amount per withdrawal
        uint256 dailyLimit;          // Maximum amount per day
        uint256 cooldownPeriod;      // Time between withdrawals
    }

    ReservePool public pool;
    WithdrawalLimit public withdrawalLimit;
    
    uint256 public constant EMERGENCY_COOLDOWN = 7 days;
    uint256 public constant MAX_EMERGENCY_LEVEL = 3;
    
    mapping(uint256 => uint256) public dailyWithdrawals;    // timestamp => amount
    mapping(address => uint256) public lastActionTime;       // For rate limiting
    
    event ReserveFunded(uint256 amount, uint256 timestamp);
    event EmergencyWithdrawal(uint256 amount, string reason, uint256 emergencyLevel);
    event EmergencyModeUpdated(bool status, uint256 emergencyLevel, uint256 timestamp);
    event WithdrawalLimitsUpdated(uint256 maxAmount, uint256 dailyLimit, uint256 cooldownPeriod);
    event RateLimitExceeded(address indexed actor, string action, uint256 timestamp);

    constructor(uint256 _minimumThreshold) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        
        pool = ReservePool({
            totalReserves: 0,
            minimumThreshold: _minimumThreshold,
            lastWithdrawalTime: 0,
            emergencyMode: false,
            emergencyLevel: 0,
            totalWithdrawals: 0
        });

        withdrawalLimit = WithdrawalLimit({
            maxAmount: _minimumThreshold / 4,     // 25% of minimum threshold
            dailyLimit: _minimumThreshold / 2,    // 50% of minimum threshold
            cooldownPeriod: 1 days                // 1 day between withdrawals
        });
    }

    modifier rateLimited() {
        if (block.timestamp < lastActionTime[msg.sender] + 1 hours)
            revert RateLimitError(lastActionTime[msg.sender] + 1 hours);
        lastActionTime[msg.sender] = block.timestamp;
        _;
    }

    modifier checkDailyLimit(uint256 amount) {
        uint256 today = block.timestamp / 1 days;
        if (dailyWithdrawals[today] + amount > withdrawalLimit.dailyLimit)
            revert DailyWithdrawalLimitExceeded(amount, withdrawalLimit.dailyLimit - dailyWithdrawals[today]);
        _;
        dailyWithdrawals[today] += amount;
    }

    function fundReserve() external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert NoFundsSent();
        pool.totalReserves += msg.value;
        emit ReserveFunded(msg.value, block.timestamp);
    }

    function setEmergencyMode(bool status, uint256 level) external onlyRole(RISK_MANAGER_ROLE) {
        if (level > MAX_EMERGENCY_LEVEL) revert InvalidEmergencyLevel(level);
        
        if (!status) {
            if (!pool.emergencyMode) revert NotInEmergencyMode();
            if (pool.totalReserves < pool.minimumThreshold) revert ReservesBelowMinimumThreshold();
        } else {
            if (pool.emergencyMode) revert AlreadyInEmergencyMode();
        }

        if (block.timestamp < lastActionTime[msg.sender] + 1 hours)
            revert RateLimitError(lastActionTime[msg.sender] + 1 hours);
        lastActionTime[msg.sender] = block.timestamp;
        
        pool.emergencyMode = status;
        pool.emergencyLevel = level;
        
        emit EmergencyModeUpdated(status, level, block.timestamp);
    }

    function withdrawEmergencyFunds(
        address payable recipient,
        uint256 amount,
        string memory reason
    ) external onlyRole(RISK_MANAGER_ROLE) {
        if (!pool.emergencyMode) revert NotInEmergencyMode();
        if (block.timestamp < pool.lastWithdrawalTime + withdrawalLimit.cooldownPeriod)
            revert CooldownPeriodNotElapsed(pool.lastWithdrawalTime + withdrawalLimit.cooldownPeriod);
        if (amount > withdrawalLimit.maxAmount) revert AmountExceedsMaximum(amount, withdrawalLimit.maxAmount);
        
        uint256 remainingReserves = pool.totalReserves - amount;
        if (remainingReserves < pool.minimumThreshold) 
            revert WithdrawalBreachesMinimumThreshold(remainingReserves, pool.minimumThreshold);
        
        uint256 today = block.timestamp / 1 days;
        if (dailyWithdrawals[today] + amount > withdrawalLimit.dailyLimit)
            revert DailyWithdrawalLimitExceeded(amount, withdrawalLimit.dailyLimit - dailyWithdrawals[today]);

        if (block.timestamp < lastActionTime[msg.sender] + 1 hours)
            revert RateLimitError(lastActionTime[msg.sender] + 1 hours);
        lastActionTime[msg.sender] = block.timestamp;
        
        pool.totalReserves = remainingReserves;
        pool.totalWithdrawals += amount;
        pool.lastWithdrawalTime = block.timestamp;
        dailyWithdrawals[today] += amount;

        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit EmergencyWithdrawal(amount, reason, pool.emergencyLevel);
    }

    function setWithdrawalLimits(
        uint256 _maxAmount,
        uint256 _dailyLimit,
        uint256 _cooldownPeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_maxAmount == 0) revert InvalidMaxAmount();
        if (_dailyLimit < _maxAmount) revert DailyLimitTooLow(_dailyLimit, _maxAmount);
        if (_cooldownPeriod == 0) revert InvalidCooldownPeriod();
        
        withdrawalLimit = WithdrawalLimit({
            maxAmount: _maxAmount,
            dailyLimit: _dailyLimit,
            cooldownPeriod: _cooldownPeriod
        });
        
        emit WithdrawalLimitsUpdated(_maxAmount, _dailyLimit, _cooldownPeriod);
    }

    function getReserveStatus() external view returns (
        uint256 totalReserves,
        uint256 minimumThreshold,
        bool emergencyMode,
        uint256 emergencyLevel,
        uint256 nextWithdrawalAllowed,
        uint256 totalWithdrawals
    ) {
        return (
            pool.totalReserves,
            pool.minimumThreshold,
            pool.emergencyMode,
            pool.emergencyLevel,
            pool.lastWithdrawalTime + withdrawalLimit.cooldownPeriod,
            pool.totalWithdrawals
        );
    }

    function getCurrentDayWithdrawals() external view returns (uint256) {
        return dailyWithdrawals[block.timestamp / 1 days];
    }

    function setMinimumThreshold(uint256 newThreshold) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        rateLimited
    {
        if (newThreshold == 0) revert InvalidThreshold();
        pool.minimumThreshold = newThreshold;
    }

    receive() external payable {
        pool.totalReserves += msg.value;
        emit ReserveFunded(msg.value, block.timestamp);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
