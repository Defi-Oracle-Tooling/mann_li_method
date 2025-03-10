import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseEther } from "viem";

describe("MannLiBondToken", function () {
  async function deployBondTokenFixture() {
    const [admin, issuer, holder1, holder2] = await hre.viem.getWalletClients();
    const bondToken = await hre.viem.deployContract("MannLiBondToken");
    
    // Grant issuer role
    await bondToken.write.grantRole([
      await bondToken.read.ISSUER_ROLE(),
      getAddress(issuer.account.address)
    ]);

    const publicClient = await hre.viem.getPublicClient();

    return {
      bondToken,
      admin,
      issuer,
      holder1,
      holder2,
      publicClient,
    };
  }

  describe("Deployment", function () {
    it("Should set the correct admin role", async function () {
      const { bondToken, admin } = await loadFixture(deployBondTokenFixture);
      const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
      expect(await bondToken.read.hasRole([DEFAULT_ADMIN_ROLE, getAddress(admin.account.address)])).to.be.true;
    });

    it("Should have correct name and symbol", async function () {
      const { bondToken } = await loadFixture(deployBondTokenFixture);
      expect(await bondToken.read.name()).to.equal("Mann Li Bond");
      expect(await bondToken.read.symbol()).to.equal("MLB");
    });
  });

  describe("Bond Issuance", function () {
    it("Should allow issuer to issue bonds", async function () {
      const { bondToken, issuer, holder1 } = await loadFixture(deployBondTokenFixture);
      const amount = parseEther("1000");
      
      const bondTokenAsIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: issuer } }
      );

      await bondTokenAsIssuer.write.issueBond([getAddress(holder1.account.address), amount]);
      expect(await bondToken.read.balanceOf([getAddress(holder1.account.address)])).to.equal(amount);
    });

    it("Should fail if non-issuer tries to issue bonds", async function () {
      const { bondToken, holder1, holder2 } = await loadFixture(deployBondTokenFixture);
      const amount = parseEther("1000");
      
      const bondTokenAsNonIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: holder1 } }
      );

      await expect(
        bondTokenAsNonIssuer.write.issueBond([getAddress(holder2.account.address), amount])
      ).to.be.rejected;
    });
  });

  describe("Interest Rates", function () {
    it("Should return correct initial rate", async function () {
      const { bondToken, issuer, holder1 } = await loadFixture(deployBondTokenFixture);
      const amount = parseEther("1000");
      
      const bondTokenAsIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: issuer } }
      );

      await bondTokenAsIssuer.write.issueBond([getAddress(holder1.account.address), amount]);
      expect(await bondToken.read.getCurrentRate([getAddress(holder1.account.address)])).to.equal(1000n); // 10%
    });

    it("Should step down rate after 5 years", async function () {
      const { bondToken, issuer, holder1 } = await loadFixture(deployBondTokenFixture);
      const amount = parseEther("1000");
      
      const bondTokenAsIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: issuer } }
      );

      await bondTokenAsIssuer.write.issueBond([getAddress(holder1.account.address), amount]);
      
      // Advance time by 5 years and 1 day
      await time.increase(5 * 365 * 24 * 60 * 60 + 86400);
      
      expect(await bondToken.read.getCurrentRate([getAddress(holder1.account.address)])).to.equal(775n); // 7.75%
    });
  });

  describe("Coupon Payments", function () {
    it("Should correctly calculate and pay coupons", async function () {
      const { bondToken, issuer, holder1 } = await loadFixture(deployBondTokenFixture);
      const amount = parseEther("1000");
      
      const bondTokenAsIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: issuer } }
      );

      await bondTokenAsIssuer.write.issueBond([getAddress(holder1.account.address), amount]);
      
      const initialBalance = await bondToken.read.balanceOf([getAddress(holder1.account.address)]);
      await bondTokenAsIssuer.write.payCoupon([getAddress(holder1.account.address)]);
      const finalBalance = await bondToken.read.balanceOf([getAddress(holder1.account.address)]);
      
      // Should increase by 10% (initial rate)
      expect(finalBalance - initialBalance).to.equal(amount * 1000n / 10000n);
    });

    it("Should fail to pay coupons for non-holders", async function () {
      const { bondToken, issuer, holder2 } = await loadFixture(deployBondTokenFixture);
      
      const bondTokenAsIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: issuer } }
      );

      await expect(
        bondTokenAsIssuer.write.payCoupon([getAddress(holder2.account.address)])
      ).to.be.rejected;
    });
  });

  describe("Access Control", function () {
    it("Should allow admin to pause and unpause", async function () {
      const { bondToken, admin } = await loadFixture(deployBondTokenFixture);
      
      await bondToken.write.pause();
      expect(await bondToken.read.paused()).to.be.true;
      
      await bondToken.write.unpause();
      expect(await bondToken.read.paused()).to.be.false;
    });

    it("Should prevent operations when paused", async function () {
      const { bondToken, issuer, holder1 } = await loadFixture(deployBondTokenFixture);
      const amount = parseEther("1000");
      
      await bondToken.write.pause();
      
      const bondTokenAsIssuer = await hre.viem.getContractAt(
        "MannLiBondToken",
        bondToken.address,
        { client: { wallet: issuer } }
      );

      await expect(
        bondTokenAsIssuer.write.issueBond([getAddress(holder1.account.address), amount])
      ).to.be.rejected;
    });
  });
});