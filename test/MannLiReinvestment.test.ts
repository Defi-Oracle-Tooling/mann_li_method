import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseEther } from "viem";

describe("MannLiReinvestment", function () {
  async function deployReinvestmentFixture() {
    const [admin, manager, holder1, holder2] = await hre.viem.getWalletClients();
    
    // Deploy bond token first
    const bondToken = await hre.viem.deployContract("MannLiBondToken");
    
    // Deploy reinvestment contract
    const reinvestment = await hre.viem.deployContract("MannLiReinvestment", [bondToken.address]);
    
    // Grant manager role
    await reinvestment.write.grantRole([
      await reinvestment.read.MANAGER_ROLE(),
      getAddress(manager.account.address)
    ]);

    const publicClient = await hre.viem.getPublicClient();

    return {
      bondToken,
      reinvestment,
      admin,
      manager,
      holder1,
      holder2,
      publicClient,
    };
  }

  describe("Deployment", function () {
    it("Should set the correct bond token address", async function () {
      const { reinvestment, bondToken } = await loadFixture(deployReinvestmentFixture);
      expect(await reinvestment.read.bondToken()).to.equal(bondToken.address);
    });

    it("Should set default reinvestment rate to 30%", async function () {
      const { reinvestment } = await loadFixture(deployReinvestmentFixture);
      const pool = await reinvestment.read.pool();
      expect(pool.reinvestmentRate).to.equal(3000n);
    });
  });

  describe("Reinvestment Rate Management", function () {
    it("Should allow manager to set reinvestment rate within bounds", async function () {
      const { reinvestment, manager } = await loadFixture(deployReinvestmentFixture);
      
      const reinvestmentAsManager = await hre.viem.getContractAt(
        "MannLiReinvestment",
        reinvestment.address,
        { client: { wallet: manager } }
      );

      await reinvestmentAsManager.write.setReinvestmentRate([4000n]); // 40%
      const pool = await reinvestment.read.pool();
      expect(pool.reinvestmentRate).to.equal(4000n);
    });

    it("Should fail when setting rate outside bounds", async function () {
      const { reinvestment, manager } = await loadFixture(deployReinvestmentFixture);
      
      const reinvestmentAsManager = await hre.viem.getContractAt(
        "MannLiReinvestment",
        reinvestment.address,
        { client: { wallet: manager } }
      );

      await expect(
        reinvestmentAsManager.write.setReinvestmentRate([5500n]) // 55%
      ).to.be.rejected;

      await expect(
        reinvestmentAsManager.write.setReinvestmentRate([1500n]) // 15%
      ).to.be.rejected;
    });
  });

  describe("Yield Reinvestment", function () {
    it("Should correctly reinvest yields", async function () {
      const { reinvestment, manager } = await loadFixture(deployReinvestmentFixture);
      
      const reinvestmentAsManager = await hre.viem.getContractAt(
        "MannLiReinvestment",
        reinvestment.address,
        { client: { wallet: manager } }
      );

      // Send some ETH to the contract to simulate yields
      await manager.sendTransaction({
        to: reinvestment.address,
        value: parseEther("10")
      });

      await reinvestmentAsManager.write.reinvestYield();
      const pool = await reinvestment.read.pool();
      expect(pool.totalFunds).to.equal(parseEther("3")); // 30% of 10 ETH
    });

    it("Should fail reinvestment with no funds", async function () {
      const { reinvestment, manager } = await loadFixture(deployReinvestmentFixture);
      
      const reinvestmentAsManager = await hre.viem.getContractAt(
        "MannLiReinvestment",
        reinvestment.address,
        { client: { wallet: manager } }
      );

      await expect(
        reinvestmentAsManager.write.reinvestYield()
      ).to.be.rejected;
    });
  });

  describe("Buyback Mechanism", function () {
    it("Should execute buyback correctly", async function () {
      const { reinvestment, bondToken, manager, holder1 } = await loadFixture(deployReinvestmentFixture);
      const amount = parseEther("1");
      
      // First issue some bonds to holder1
      await bondToken.write.grantRole([
        await bondToken.read.ISSUER_ROLE(),
        getAddress(manager.account.address)
      ]);
      
      const bondTokenAsManager = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: manager } }
      );
      
      await bondTokenAsManager.write.issueBond([getAddress(holder1.account.address), amount]);
      
      // Fund the reinvestment contract
      await manager.sendTransaction({
        to: reinvestment.address,
        value: parseEther("2")
      });

      const reinvestmentAsManager = await hre.viem.getContractAt(
        "MannLiReinvestment",
        reinvestment.address,
        { client: { wallet: manager } }
      );

      // Approve reinvestment contract to spend holder's bonds
      const bondTokenAsHolder = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: holder1 } }
      );
      
      await bondTokenAsHolder.write.approve([reinvestment.address, amount]);

      const initialBalance = await bondToken.read.balanceOf([getAddress(holder1.account.address)]);
      await reinvestmentAsManager.write.executeBuyback([getAddress(holder1.account.address), amount]);
      const finalBalance = await bondToken.read.balanceOf([getAddress(holder1.account.address)]);
      
      expect(finalBalance).to.be.lessThan(initialBalance);
    });
  });

  describe("Emergency Functions", function () {
    it("Should allow admin to withdraw in emergency", async function () {
      const { reinvestment, admin } = await loadFixture(deployReinvestmentFixture);
      
      // Fund the contract
      await admin.sendTransaction({
        to: reinvestment.address,
        value: parseEther("1")
      });

      const initialBalance = await reinvestment.read.pool().then(p => p.totalFunds);
      await reinvestment.write.emergencyWithdraw();
      const finalBalance = await reinvestment.read.pool().then(p => p.totalFunds);
      
      expect(finalBalance).to.be.lessThan(initialBalance);
    });
  });
});