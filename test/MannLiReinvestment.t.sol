// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MannLiReinvestment} from "../contracts/MannLiReinvestment.sol";
import {MannLiBondToken} from "../contracts/MannLiBondToken.sol";

contract MannLiReinvestmentTest is Test {
    MannLiReinvestment public reinvestment;
    MannLiBondToken public bondToken;
    address public admin;
    address public manager;
    address public holder;
    uint256 public constant INITIAL_AMOUNT = 10 ether;
    uint256 public constant REINVEST_AMOUNT = 20 ether;
    
    function setUp() public {
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        holder = makeAddr("holder");

        vm.startPrank(admin);
        // Deploy bond token
        bondToken = new MannLiBondToken();
        
        // Deploy reinvestment contract
        reinvestment = new MannLiReinvestment(address(bondToken));
        reinvestment.grantRole(reinvestment.MANAGER_ROLE(), manager);
        
        // Grant issuer role to manager and reinvestment contract for bond token
        bondToken.grantRole(bondToken.ISSUER_ROLE(), manager);
        bondToken.grantRole(bondToken.ISSUER_ROLE(), address(reinvestment));
        vm.stopPrank();

        // Fund accounts
        vm.deal(manager, 100 ether);
        vm.deal(holder, 100 ether);
    }

    function test_InitialState() public view {
        assertEq(address(reinvestment.bondToken()), address(bondToken));
        (uint256 totalReinvested, uint256 totalBuybacks, uint256 currentFunds, uint256 reinvestmentRate) = reinvestment.getReinvestmentStats();
        assertEq(totalReinvested, 0);
        assertEq(totalBuybacks, 0);
        assertEq(currentFunds, 0);
        assertEq(reinvestmentRate, 3000); // 30% default rate
    }

    function test_ReinvestmentRate() public {
        vm.startPrank(manager);
        reinvestment.setReinvestmentRate(4000); // 40%
        vm.stopPrank();

        (,,, uint256 rate) = reinvestment.getReinvestmentStats();
        assertEq(rate, 4000);
    }

    function test_YieldReinvestment() public {
        payable(address(reinvestment)).transfer(REINVEST_AMOUNT);

        vm.prank(manager);
        reinvestment.reinvestYield();

        (uint256 totalReinvested,,uint256 currentFunds,) = reinvestment.getReinvestmentStats();
        assertEq(totalReinvested, (REINVEST_AMOUNT * 3000) / 10000); // 30% of REINVEST_AMOUNT
        assertEq(currentFunds, (REINVEST_AMOUNT * 3000) / 10000);
    }

    function test_Buyback() public {
        uint256 bondAmount = 5 ether; // Reduced to be less than reinvested amount
        
        // Issue bonds to holder
        vm.prank(manager);
        bondToken.issueBond(holder, bondAmount);
        
        // Fund reinvestment contract
        vm.prank(manager);
        (bool success,) = address(reinvestment).call{value: 20 ether}("");
        assertTrue(success);

        // Reinvest funds first
        vm.prank(manager);
        reinvestment.reinvestYield();

        // Approve reinvestment contract
        vm.prank(holder);
        bondToken.approve(address(reinvestment), bondAmount);

        // Warp time to handle cooldown period
        vm.warp(block.timestamp + 31 days);

        // Execute buyback
        vm.prank(manager);
        reinvestment.executeBuyback(holder, bondAmount);

        (,uint256 totalBuybacks,uint256 currentFunds,) = reinvestment.getReinvestmentStats();
        assertEq(totalBuybacks, bondAmount);
        assertEq(bondToken.balanceOf(holder), 0);
        // Should have deducted the buyback amount (minus discount) from currentFunds
        assertEq(currentFunds, (20 ether * 3000 / 10000) - (bondAmount * 9500 / 10000));
    }

    function testFuzz_ReinvestmentWithinBounds(uint256 rate) public {
        vm.assume(rate >= 2000 && rate <= 5000);
        
        vm.prank(manager);
        reinvestment.setReinvestmentRate(rate);

        (,,, uint256 newRate) = reinvestment.getReinvestmentStats();
        assertEq(newRate, rate);
    }

    receive() external payable {}
}