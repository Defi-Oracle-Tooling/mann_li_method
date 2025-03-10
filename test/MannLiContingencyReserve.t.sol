// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MannLiContingencyReserve} from "../contracts/MannLiContingencyReserve.sol";

contract MannLiContingencyReserveTest is Test {
    MannLiContingencyReserve public reserve;
    address public admin;
    address public riskManager;
    address public user;
    uint256 public minimumThreshold;

    function setUp() public {
        admin = makeAddr("admin");
        riskManager = makeAddr("riskManager");
        user = makeAddr("user");
        minimumThreshold = 1000 ether;

        vm.startPrank(admin);
        reserve = new MannLiContingencyReserve(minimumThreshold);
        reserve.grantRole(reserve.RISK_MANAGER_ROLE(), riskManager);
        vm.stopPrank();

        // Fund accounts
        vm.deal(user, 100 ether);
        vm.deal(riskManager, 100 ether);
    }

    function test_InitialState() public {
        (
            uint256 totalReserves,
            uint256 minThreshold,
            bool emergencyMode,
            uint256 emergencyLevel,
            ,
            uint256 totalWithdrawals
        ) = reserve.getReserveStatus();

        assertEq(totalReserves, 0);
        assertEq(minThreshold, minimumThreshold);
        assertFalse(emergencyMode);
        assertEq(emergencyLevel, 0);
        assertEq(totalWithdrawals, 0);
    }

    function test_FundingReserve() public {
        uint256 fundAmount = 10 ether;
        vm.prank(user);
        reserve.fundReserve{value: fundAmount}();

        (uint256 totalReserves,,,,, ) = reserve.getReserveStatus();
        assertEq(totalReserves, fundAmount);
    }

    function test_EmergencyMode() public {
        uint256 fundAmount = 10 ether;
        vm.prank(user);
        reserve.fundReserve{value: fundAmount}();

        vm.prank(riskManager);
        reserve.setEmergencyMode(true, 1);

        (,, bool emergencyMode, uint256 emergencyLevel,,) = reserve.getReserveStatus();
        assertTrue(emergencyMode);
        assertEq(emergencyLevel, 1);
    }

    function test_EmergencyWithdrawal() public {
        uint256 fundAmount = 10 ether;
        uint256 withdrawAmount = 5 ether;
        
        // Fund the reserve
        vm.prank(user);
        reserve.fundReserve{value: fundAmount}();

        // Activate emergency mode
        vm.prank(riskManager);
        reserve.setEmergencyMode(true, 1);

        // Wait for cooldown
        vm.warp(block.timestamp + 7 days);

        // Withdraw funds
        vm.prank(riskManager);
        reserve.withdrawEmergencyFunds(payable(user), withdrawAmount, "Emergency test");

        (uint256 totalReserves,,,,, uint256 totalWithdrawals) = reserve.getReserveStatus();
        assertEq(totalReserves, fundAmount - withdrawAmount);
        assertEq(totalWithdrawals, withdrawAmount);
    }

    function testFuzz_FundingReserve(uint256 amount) public {
        vm.assume(amount > 0.1 ether && amount < 1000 ether);
        vm.deal(user, amount);

        vm.prank(user);
        reserve.fundReserve{value: amount}();

        (uint256 totalReserves,,,,, ) = reserve.getReserveStatus();
        assertEq(totalReserves, amount);
    }

    receive() external payable {}
}