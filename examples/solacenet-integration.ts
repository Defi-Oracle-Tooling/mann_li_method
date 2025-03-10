// Example of importing and using Mann Li Method in SolaceNet

import { ethers } from 'ethers';
import { MannLiBondToken } from 'libs/mann_li_method/types/MannLiBondToken';

// Example function to issue a bond
export async function issueBond(
  bondTokenAddress: string,
  holderAddress: string,
  amount: string,
  provider: ethers.providers.Provider,
  signer: ethers.Signer
): Promise<ethers.ContractTransaction> {
  // Create contract instance
  const bondToken = new ethers.Contract(
    bondTokenAddress,
    MannLiBondToken.abi,
    signer
  ) as MannLiBondToken;
  
  // Issue bond
  return await bondToken.issueBond(
    holderAddress,
    ethers.utils.parseEther(amount)
  );
}

// Example function to get bond information
export async function getBondInfo(
  bondTokenAddress: string,
  holderAddress: string,
  provider: ethers.providers.Provider
): Promise<any> {
  // Create contract instance
  const bondToken = new ethers.Contract(
    bondTokenAddress,
    MannLiBondToken.abi,
    provider
  ) as MannLiBondToken;
  
  // Get bond information
  const bondInfo = await bondToken.bondHolders(holderAddress);
  
  return {
    issueDate: bondInfo.issueDate.toNumber(),
    maturityDate: bondInfo.maturityDate.toNumber(),
    initialRate: bondInfo.initialRate.toNumber() / 100, // Convert to percentage
    stepDownRate: bondInfo.stepDownRate.toNumber() / 100, // Convert to percentage
    stepDownDate: bondInfo.stepDownDate.toNumber(),
    maturityClaimed: bondInfo.maturityClaimed,
    seriesId: bondInfo.seriesId.toNumber()
  };
}
