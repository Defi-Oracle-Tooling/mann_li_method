// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MannLiBondToken} from "../contracts/MannLiBondToken.sol";

contract MannLiBondTokenTest is Test {
    MannLiBondToken public bondToken;
    address public admin;
    address public issuer;
    address public holder1;
    address public holder2;

    function setUp() public {
        admin = makeAddr("admin");
        issuer = makeAddr("issuer");
        holder1 = makeAddr("holder1");
        holder2 = makeAddr("holder2");

        vm.startPrank(admin);
        bondToken = new MannLiBondToken();
        bondToken.grantRole(bondToken.ISSUER_ROLE(), issuer);
        vm.stopPrank();
    }

    function test_InitialState() public {
        assertEq(bondToken.name(), "Mann Li Bond");
        assertEq(bondToken.symbol(), "MLB");
        assertTrue(bondToken.hasRole(bondToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(bondToken.hasRole(bondToken.ISSUER_ROLE(), issuer));
    }

    function test_BondIssuance() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(issuer);
        bondToken.issueBond(holder1, amount);
        vm.stopPrank();

        assertEq(bondToken.balanceOf(holder1), amount);
        assertEq(bondToken.totalBondsIssued(), amount);
    }

    function test_StepDownRate() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(issuer);
        bondToken.issueBond(holder1, amount);
        vm.stopPrank();

        assertEq(bondToken.getCurrentRate(holder1), 1000); // 10%

        // Jump 5 years ahead
        vm.warp(block.timestamp + 5 * 365 days + 1 days);
        assertEq(bondToken.getCurrentRate(holder1), 775); // 7.75%
    }

    function test_TransferRestrictions() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(issuer);
        bondToken.issueBond(holder1, amount);
        bondToken.setTransferRestriction(holder1, true);
        vm.stopPrank();

        vm.startPrank(holder1);
        vm.expectRevert("Sender is restricted");
        bondToken.transfer(holder2, amount);
        vm.stopPrank();
    }

    function testFuzz_CouponPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1_000_000 ether);
        
        vm.startPrank(issuer);
        bondToken.issueBond(holder1, amount);
        uint256 initialBalance = bondToken.balanceOf(holder1);
        bondToken.payCoupon(holder1);
        vm.stopPrank();

        uint256 expectedIncrease = (amount * 1000) / 10000; // 10% of amount
        assertEq(bondToken.balanceOf(holder1) - initialBalance, expectedIncrease);
    }
}