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
        
        // Grant issuer role to manager for bond token
        bondToken.grantRole(bondToken.ISSUER_ROLE(), manager);
        vm.stopPrank();

        // Fund accounts
        vm.deal(manager, 100 ether);
        vm.deal(holder, 100 ether);
    }

    function test_InitialState() public {
        assertEq(address(reinvestment.bondToken()), address(bondToken));
        (,,, uint256 rate) = reinvestment.getReinvestmentStats();
        assertEq(rate, 3000); // 30% default rate
    }

    function test_ReinvestmentRate() public {
        vm.startPrank(manager);
        reinvestment.setReinvestmentRate(4000); // 40%
        vm.stopPrank();

        (,,, uint256 rate) = reinvestment.getReinvestmentStats();
        assertEq(rate, 4000);
    }

    function test_YieldReinvestment() public {
        uint256 yieldAmount = 10 ether;
        
        // Send yield to contract
        vm.prank(manager);
        (bool success,) = address(reinvestment).call{value: yieldAmount}("");
        assertTrue(success);

        // Reinvest yield
        vm.prank(manager);
        reinvestment.reinvestYield();

        (uint256 totalReinvested,,uint256 currentFunds,) = reinvestment.getReinvestmentStats();
        assertEq(currentFunds, 3 ether); // 30% of 10 ETH
        assertEq(totalReinvested, 3 ether);
    }

    function test_Buyback() public {
        uint256 bondAmount = 10 ether;
        
        // Issue bonds to holder
        vm.prank(manager);
        bondToken.issueBond(holder, bondAmount);
        
        // Fund reinvestment contract
        vm.prank(manager);
        (bool success,) = address(reinvestment).call{value: 20 ether}("");
        assertTrue(success);

        // Approve reinvestment contract
        vm.prank(holder);
        bondToken.approve(address(reinvestment), bondAmount);

        // Execute buyback
        vm.prank(manager);
        reinvestment.executeBuyback(holder, bondAmount);

        (,uint256 totalBuybacks,uint256 currentFunds,) = reinvestment.getReinvestmentStats();
        assertGt(totalBuybacks, 0);
        assertLt(currentFunds, 20 ether);
        assertEq(bondToken.balanceOf(holder), 0);
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