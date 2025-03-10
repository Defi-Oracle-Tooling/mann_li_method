# Azure Deployment Guide

This guide provides instructions for deploying the Mann Li Method project to Azure.

## Prerequisites

- Azure subscription
- Azure CLI installed
- Node.js and pnpm installed
- Foundry installed

## Infrastructure Deployment

The project uses Azure Resource Manager (ARM) templates to deploy the required infrastructure:

```bash
# Navigate to the azure directory
cd azure

# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

This will create:
- Resource Group
- Storage Account
- Key Vault
- App Service Plan
- Function App

## Smart Contract Deployment

Smart contracts are deployed using GitHub Actions workflow:

1. Set up the following secrets in your GitHub repository:
   - `AZURE_CREDENTIALS`: Azure service principal credentials
   - `AZURE_BLOCKCHAIN_RPC_URL`: RPC URL for the Azure Blockchain Service
   - `DEPLOYMENT_PRIVATE_KEY`: Private key for contract deployment

2. Push changes to the `master` branch to trigger the deployment workflow.

3. Monitor the deployment in the GitHub Actions tab.

## Website Deployment

The website is deployed using Azure Static Web Apps:

1. Set up the following secret in your GitHub repository:
   - `AZURE_STATIC_WEB_APPS_API_TOKEN`: API token for Azure Static Web Apps

2. Push changes to the `master` branch to trigger the deployment workflow.

3. Monitor the deployment in the GitHub Actions tab.

## Manual Deployment

If you prefer to deploy manually:

### Smart Contracts

```bash
# Build contracts
forge build

# Run tests
forge test

# Deploy contracts
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Website

```bash
# Navigate to website directory
cd website

# Install dependencies
pnpm install

# Build website
pnpm run build

# Deploy to Azure Static Web Apps
az staticwebapp deploy --source-location dist --app-name YOUR_STATIC_WEB_APP_NAME
```
