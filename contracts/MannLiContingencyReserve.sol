// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title MannLiContingencyReserve
 * @dev Manages the 20% contingency reserve allocation for risk mitigation
 */
contract MannLiContingencyReserve is AccessControl, ReentrancyGuard, Pausable {
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
        require(
            block.timestamp >= lastActionTime[msg.sender] + 1 hours,
            "Rate limit: Too many actions"
        );
        lastActionTime[msg.sender] = block.timestamp;
        _;
    }

    modifier checkDailyLimit(uint256 amount) {
        uint256 today = block.timestamp / 1 days;
        require(
            dailyWithdrawals[today] + amount <= withdrawalLimit.dailyLimit,
            "Daily withdrawal limit exceeded"
        );
        _;
        dailyWithdrawals[today] += amount;
    }

    function fundReserve() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must send funds");
        pool.totalReserves += msg.value;
        emit ReserveFunded(msg.value, block.timestamp);
    }

    function setEmergencyMode(bool status, uint256 level) 
        external 
        onlyRole(RISK_MANAGER_ROLE)
        rateLimited 
    {
        require(level <= MAX_EMERGENCY_LEVEL, "Invalid emergency level");
        if (status) {
            require(!pool.emergencyMode, "Already in emergency mode");
            pool.emergencyMode = true;
            pool.emergencyLevel = level;
        } else {
            require(pool.emergencyMode, "Not in emergency mode");
            require(
                pool.totalReserves >= pool.minimumThreshold,
                "Reserves below minimum threshold"
            );
            pool.emergencyMode = false;
            pool.emergencyLevel = 0;
        }
        emit EmergencyModeUpdated(status, level, block.timestamp);
    }

    function withdrawEmergencyFunds(
        address payable recipient,
        uint256 amount,
        string calldata reason
    ) 
        external 
        nonReentrant 
        onlyRole(RISK_MANAGER_ROLE)
        checkDailyLimit(amount)
        whenNotPaused 
    {
        require(pool.emergencyMode, "Not in emergency mode");
        require(
            block.timestamp >= pool.lastWithdrawalTime + withdrawalLimit.cooldownPeriod,
            "Cooldown period not elapsed"
        );
        require(amount <= withdrawalLimit.maxAmount, "Amount exceeds maximum");
        require(amount <= pool.totalReserves, "Insufficient reserves");
        require(recipient != address(0), "Invalid recipient");
        
        // Adjust withdrawal limit based on emergency level
        uint256 adjustedLimit = withdrawalLimit.maxAmount;
        if (pool.emergencyLevel == 2) {
            adjustedLimit = (withdrawalLimit.maxAmount * 150) / 100; // 150%
        } else if (pool.emergencyLevel == 3) {
            adjustedLimit = (withdrawalLimit.maxAmount * 200) / 100; // 200%
        }
        require(amount <= adjustedLimit, "Amount exceeds emergency limit");
        
        pool.totalReserves -= amount;
        pool.lastWithdrawalTime = block.timestamp;
        pool.totalWithdrawals += amount;
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit EmergencyWithdrawal(amount, reason, pool.emergencyLevel);
    }

    function setWithdrawalLimits(
        uint256 _maxAmount,
        uint256 _dailyLimit,
        uint256 _cooldownPeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxAmount > 0, "Invalid max amount");
        require(_dailyLimit >= _maxAmount, "Daily limit too low");
        require(_cooldownPeriod > 0, "Invalid cooldown period");
        
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
        require(newThreshold > 0, "Invalid threshold");
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