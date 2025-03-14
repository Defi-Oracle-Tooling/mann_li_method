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
        vm.expectRevert(MannLiBondToken.SenderRestricted.selector);
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

    function test_AccessControl() public {
        address unauthorized = makeAddr("unauthorized");
        uint256 amount = 1000 ether;
        bytes32 issuerRole = bondToken.ISSUER_ROLE();

        // Try to issue bond without role
        vm.prank(unauthorized);
        vm.expectRevert(bytes(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            issuerRole
        )));
        bondToken.issueBond(holder1, amount);
        
        // Try to pay coupon without role
        vm.prank(unauthorized);
        vm.expectRevert(bytes(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            issuerRole
        )));
        bondToken.payCoupon(holder1);
        
        // Try to set transfer restriction without role
        vm.prank(unauthorized);
        vm.expectRevert(bytes(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            issuerRole
        )));
        bondToken.setTransferRestriction(holder1, true);

        // Grant role and verify it works
        vm.prank(admin);
        bondToken.grantRole(issuerRole, unauthorized);
        
        vm.prank(unauthorized);
        bondToken.issueBond(holder1, amount);
        assertEq(bondToken.balanceOf(holder1), amount);
    }

    function test_PauseFunctionality() public {
        uint256 amount = 1000 ether;
        bytes32 adminRole = bondToken.DEFAULT_ADMIN_ROLE();
        
        // Issue bond
        vm.prank(issuer);
        bondToken.issueBond(holder1, amount);
        
        // Try to pause without admin role
        vm.prank(issuer);
        // Using bytes4 selector for OpenZeppelin v5.0 custom error
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")),
                issuer,
                adminRole
            )
        );
        bondToken.pause();
        
        // Pause with admin role
        vm.prank(admin);
        bondToken.pause();
        assertTrue(bondToken.paused());
        
        // Verify operations are blocked when paused
        vm.startPrank(issuer);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bondToken.issueBond(holder1, amount);
        
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bondToken.payCoupon(holder1);
        vm.stopPrank();
        
        // For transfer, we need to add some time to get past the lockup period
        // otherwise we'll hit the "Transfer locked during initial period" error
        // instead of the pause error
        vm.warp(block.timestamp + 31 days);
        
        vm.prank(holder1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        bondToken.transfer(holder2, amount);
        
        // Unpause and verify operations work again
        vm.prank(admin);
        bondToken.unpause();
        assertFalse(bondToken.paused());
        
        vm.prank(issuer);
        bondToken.issueBond(holder1, amount);
        assertEq(bondToken.balanceOf(holder1), amount * 2);
    }
    
    function test_RateAdjustment() public {
        uint256 amount = 1000 ether;
        
        // Create a new bond series
        vm.startPrank(admin);
        uint256 seriesId = bondToken.createBondSeries(
            "Test Series",
            1200, // 12% initial rate
            900,  // 9% step-down rate
            3650, // 10 years maturity
            1825  // 5 years step-down
        );
        
        // Wait for rate limit to expire
        vm.warp(block.timestamp + 1 hours + 1 minutes);
        
        // Adjust rates
        bondToken.adjustSeriesRates(seriesId, 1100, 800);
        vm.stopPrank();
        
        // Issue bond from the new series
        vm.prank(issuer);
        bondToken.issueBondFromSeries(holder1, amount, seriesId);
        
        // Get series info and verify rates were updated
        (
            string memory name,
            uint256 initialRate,
            uint256 stepDownRate,
            ,
            ,
            bool active
        ) = bondToken.getBondSeriesInfo(seriesId);
        
        assertEq(initialRate, 1100);
        assertEq(stepDownRate, 800);
        assertTrue(active);
    }
    
    function test_EarlyRedemption() public {
        uint256 amount = 1000 ether;
        
        vm.startPrank(issuer);
        bondToken.issueBond(holder1, amount);
        vm.stopPrank();
        
        uint256 initialBalance = bondToken.balanceOf(holder1);
        assertEq(initialBalance, amount);
        
        // Wait for lockup period to pass
        vm.warp(block.timestamp + 31 days);
        
        // Redeem early
        vm.prank(holder1);
        bondToken.redeemEarly(500 ether);
        
        // Verify balance after redemption
        uint256 finalBalance = bondToken.balanceOf(holder1);
        assertEq(finalBalance, initialBalance - 500 ether);
    }
    
    function test_RateLimiting() public {
        // Create a new bond series
        vm.startPrank(admin);
        uint256 seriesId = bondToken.createBondSeries(
            "Rate Limited Series",
            1200, // 12% initial rate
            900,  // 9% step-down rate
            3650, // 10 years maturity
            1825  // 5 years step-down
        );
        
        // Wait for rate limit to expire after series creation
        vm.warp(block.timestamp + 1 hours + 1 minutes);
        
        // First rate adjustment should succeed
        bondToken.adjustSeriesRates(seriesId, 1100, 850);
        
        // Second rate adjustment should fail due to rate limiting
        vm.expectRevert(
            abi.encodeWithSelector(
                MannLiBondToken.RateLimitExceeded.selector,
                block.timestamp + 1 hours
            )
        );
        bondToken.adjustSeriesRates(seriesId, 1050, 800);
        
        // Wait for rate limit to expire
        vm.warp(block.timestamp + 1 hours + 1 minutes);
        
        // Now the adjustment should succeed
        bondToken.adjustSeriesRates(seriesId, 1050, 800);
        
        // Verify the rates were updated
        (
            ,
            uint256 initialRate,
            uint256 stepDownRate,
            ,
            ,
            bool active
        ) = bondToken.getBondSeriesInfo(seriesId);
        
        assertEq(initialRate, 1050);
        assertEq(stepDownRate, 800);
        assertTrue(active);
        vm.stopPrank();
    }
}
