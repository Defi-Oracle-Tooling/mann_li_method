// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/MannLiBondToken.sol";
import "../contracts/MannLiReinvestment.sol";
import "../contracts/MannLiContingencyReserve.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Bond Token
        MannLiBondToken bondToken = new MannLiBondToken();
        
        // Deploy Reinvestment
        MannLiReinvestment reinvestment = new MannLiReinvestment(address(bondToken));
        
        // Deploy Contingency Reserve (5 ETH minimum threshold)
        MannLiContingencyReserve reserve = new MannLiContingencyReserve(5 ether);
        
        // Set up roles
        bondToken.grantRole(bondToken.ISSUER_ROLE(), address(reinvestment));
        
        // Log deployed addresses
        console.log("MannLiBondToken deployed at:", address(bondToken));
        console.log("MannLiReinvestment deployed at:", address(reinvestment));
        console.log("MannLiContingencyReserve deployed at:", address(reserve));
        
        vm.stopBroadcast();
    }
}
