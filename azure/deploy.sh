#!/bin/bash

# Azure deployment script for Mann Li Method

# Variables
RESOURCE_GROUP="MannLiMethodRG"
LOCATION="eastus"
PROJECT_NAME="mannlimethod"

# Create resource group if it doesn't exist
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy ARM template
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file azuredeploy.json \
  --parameters projectName=$PROJECT_NAME location=$LOCATION

# Get outputs
STORAGE_ACCOUNT=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name azuredeploy \
  --query properties.outputs.storageAccountName.value \
  --output tsv)

KEY_VAULT=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name azuredeploy \
  --query properties.outputs.keyVaultName.value \
  --output tsv)

FUNCTION_APP=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name azuredeploy \
  --query properties.outputs.functionAppName.value \
  --output tsv)

echo "Deployment completed successfully!"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Key Vault: $KEY_VAULT"
echo "Function App: $FUNCTION_APP"
