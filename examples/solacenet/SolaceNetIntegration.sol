// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@mann_li_method/MannLiBondToken.sol";
import "@mann_li_method/MannLiReinvestment.sol";
import "@mann_li_method/MannLiContingencyReserve.sol";

/**
 * @title SolaceNetIntegration
 * @dev Example contract showing how to integrate Mann Li Method contracts in SolaceNet
 */
contract SolaceNetIntegration {
    MannLiBondToken public bondToken;
    MannLiReinvestment public reinvestment;
    MannLiContingencyReserve public reserve;
    
    constructor(
        address _bondToken,
        address _reinvestment,
        address _reserve
    ) {
        bondToken = MannLiBondToken(_bondToken);
        reinvestment = MannLiReinvestment(_reinvestment);
        reserve = MannLiContingencyReserve(_reserve);
    }
    
    /**
     * @dev Example function to issue a bond through SolaceNet
     */
    function issueBondThroughSolaceNet(
        address to,
        uint256 amount,
        uint256 seriesId
    ) external {
        // Assuming this contract has ISSUER_ROLE
        bondToken.issueBondFromSeries(to, amount, seriesId);
    }
    
    /**
     * @dev Example function to reinvest yield through SolaceNet
     */
    function reinvestYieldThroughSolaceNet() external {
        // Assuming this contract has MANAGER_ROLE
        reinvestment.reinvestYield();
    }
    
    /**
     * @dev Example function to fund reserve through SolaceNet
     */
    function fundReserveThroughSolaceNet() external payable {
        // Fund the reserve
        reserve.fundReserve{value: msg.value}();
    }
}
