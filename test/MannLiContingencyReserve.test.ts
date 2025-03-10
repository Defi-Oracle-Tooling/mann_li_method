import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseEther } from "viem";

describe("MannLiContingencyReserve", function () {
  async function deployContingencyReserveFixture() {
    const [admin, riskManager, user1] = await hre.viem.getWalletClients();
    const minimumThreshold = parseEther("1000"); // 1000 ETH
    
    const contingencyReserve = await hre.viem.deployContract("MannLiContingencyReserve", [minimumThreshold]);
    
    // Grant risk manager role
    await contingencyReserve.write.grantRole([
      await contingencyReserve.read.RISK_MANAGER_ROLE(),
      getAddress(riskManager.account.address)
    ]);

    const publicClient = await hre.viem.getPublicClient();

    return {
      contingencyReserve,
      minimumThreshold,
      admin,
      riskManager,
      user1,
      publicClient,
    };
  }

  describe("Deployment", function () {
    it("Should set the correct minimum threshold", async function () {
      const { contingencyReserve, minimumThreshold } = await loadFixture(deployContingencyReserveFixture);
      const pool = await contingencyReserve.read.pool();
      expect(pool.minimumThreshold).to.equal(minimumThreshold);
    });

    it("Should initialize with correct roles", async function () {
      const { contingencyReserve, admin, riskManager } = await loadFixture(deployContingencyReserveFixture);
      const RISK_MANAGER_ROLE = await contingencyReserve.read.RISK_MANAGER_ROLE();
      
      expect(await contingencyReserve.read.hasRole([RISK_MANAGER_ROLE, getAddress(riskManager.account.address)])).to.be.true;
    });
  });

  describe("Reserve Funding", function () {
    it("Should accept direct funding", async function () {
      const { contingencyReserve, user1 } = await loadFixture(deployContingencyReserveFixture);
      const amount = parseEther("10");

      await user1.sendTransaction({
        to: contingencyReserve.address,
        value: amount
      });

      const pool = await contingencyReserve.read.pool();
      expect(pool.totalReserves).to.equal(amount);
    });

    it("Should accept funding through fundReserve function", async function () {
      const { contingencyReserve, user1 } = await loadFixture(deployContingencyReserveFixture);
      const amount = parseEther("10");

      await contingencyReserve.write.fundReserve({ value: amount });
      
      const pool = await contingencyReserve.read.pool();
      expect(pool.totalReserves).to.equal(amount);
    });
  });

  describe("Emergency Mode", function () {
    it("Should allow risk manager to activate emergency mode", async function () {
      const { contingencyReserve, riskManager } = await loadFixture(deployContingencyReserveFixture);
      
      const contingencyReserveAsManager = await hre.viem.getContractAt(
        "MannLiContingencyReserve",
        contingencyReserve.address,
        { client: { wallet: riskManager } }
      );

      await contingencyReserveAsManager.write.activateEmergencyMode();
      const pool = await contingencyReserve.read.pool();
      expect(pool.emergencyMode).to.be.true;
    });

    it("Should prevent non-risk manager from activating emergency mode", async function () {
      const { contingencyReserve, user1 } = await loadFixture(deployContingencyReserveFixture);
      
      const contingencyReserveAsUser = await hre.viem.getContractAt(
        "MannLiContingencyReserve",
        contingencyReserve.address,
        { client: { wallet: user1 } }
      );

      await expect(
        contingencyReserveAsUser.write.activateEmergencyMode()
      ).to.be.rejected;
    });
  });

  describe("Emergency Withdrawals", function () {
    it("Should allow withdrawal in emergency mode after cooldown", async function () {
      const { contingencyReserve, riskManager, user1 } = await loadFixture(deployContingencyReserveFixture);
      const amount = parseEther("5");

      // Fund the reserve
      await contingencyReserve.write.fundReserve({ value: parseEther("10") });
      
      const contingencyReserveAsManager = await hre.viem.getContractAt(
        "MannLiContingencyReserve",
        contingencyReserve.address,
        { client: { wallet: riskManager } }
      );

      // Activate emergency mode
      await contingencyReserveAsManager.write.activateEmergencyMode();
      
      // Wait for cooldown period
      await time.increase(7 * 24 * 60 * 60); // 7 days
      
      await contingencyReserveAsManager.write.withdrawEmergencyFunds([
        getAddress(user1.account.address),
        amount,
        "Emergency withdrawal test"
      ]);

      const pool = await contingencyReserve.read.pool();
      expect(pool.totalReserves).to.equal(parseEther("5"));
    });

    it("Should prevent withdrawal before cooldown period", async function () {
      const { contingencyReserve, riskManager, user1 } = await loadFixture(deployContingencyReserveFixture);
      const amount = parseEther("5");

      // Fund the reserve
      await contingencyReserve.write.fundReserve({ value: parseEther("10") });
      
      const contingencyReserveAsManager = await hre.viem.getContractAt(
        "MannLiContingencyReserve",
        contingencyReserve.address,
        { client: { wallet: riskManager } }
      );

      // Activate emergency mode
      await contingencyReserveAsManager.write.activateEmergencyMode();
      
      await expect(
        contingencyReserveAsManager.write.withdrawEmergencyFunds([
          getAddress(user1.account.address),
          amount,
          "Emergency withdrawal test"
        ])
      ).to.be.rejected;
    });
  });

  describe("Reserve Status", function () {
    it("Should return correct reserve status", async function () {
      const { contingencyReserve, minimumThreshold } = await loadFixture(deployContingencyReserveFixture);
      const amount = parseEther("10");

      await contingencyReserve.write.fundReserve({ value: amount });
      
      const status = await contingencyReserve.read.getReserveStatus();
      expect(status.totalReserves).to.equal(amount);
      expect(status.minimumThreshold).to.equal(minimumThreshold);
      expect(status.emergencyMode).to.be.false;
    });
  });

  describe("Administrative Functions", function () {
    it("Should allow admin to update minimum threshold", async function () {
      const { contingencyReserve } = await loadFixture(deployContingencyReserveFixture);
      const newThreshold = parseEther("2000");

      await contingencyReserve.write.setMinimumThreshold([newThreshold]);
      
      const pool = await contingencyReserve.read.pool();
      expect(pool.minimumThreshold).to.equal(newThreshold);
    });

    it("Should allow admin to pause and unpause", async function () {
      const { contingencyReserve } = await loadFixture(deployContingencyReserveFixture);
      
      await contingencyReserve.write.pause();
      expect(await contingencyReserve.read.paused()).to.be.true;
      
      await contingencyReserve.write.unpause();
      expect(await contingencyReserve.read.paused()).to.be.false;
    });
  });
});