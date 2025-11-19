#!/usr/bin/env bash
# Create resource group + storage account + container for terraform backend
set -e
SUBSCRIPTION_ID="$1"
if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "Usage: $0 <SUBSCRIPTION_ID>"
  exit 1
fi
RG_NAME="salz-tfstate-rg"
STORAGE_ACCOUNT="salzstate$(openssl rand -hex 4)" # ensure unique
CONTAINER_NAME="tfstate"

az account set --subscription "$SUBSCRIPTION_ID"
az group create -n $RG_NAME -l eastus
az storage account create -n $STORAGE_ACCOUNT -g $RG_NAME --sku Standard_LRS --encryption-services blob
STORAGE_KEY=$(az storage account keys list -g $RG_NAME -n $STORAGE_ACCOUNT --query '[0].value' -o tsv)
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY
echo "Resource Group: $RG_NAME"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "STORAGE_KEY=$STORAGE_KEY"
