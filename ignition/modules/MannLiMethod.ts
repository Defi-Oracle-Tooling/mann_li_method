import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MINIMUM_RESERVE_THRESHOLD = "1000000000000000000000"; // 1000 ETH in wei

export default buildModule("MannLiMethod", (m) => {
    // Deploy the Bond Token contract first
    const bondToken = m.contract("MannLiBondToken");

    // Deploy the Reinvestment contract with bond token address
    const reinvestment = m.contract("MannLiReinvestment", [bondToken]);

    // Deploy Contingency Reserve with minimum threshold
    const contingencyReserve = m.contract("MannLiContingencyReserve", [
        MINIMUM_RESERVE_THRESHOLD,
    ]);

    return {
        bondToken,
        reinvestment,
        contingencyReserve,
    };
});