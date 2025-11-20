#!/usr/bin/env bash
set -euo pipefail

# terraform_deploy.sh
# Usage: ./terraform_deploy.sh [--migrate-backend] [--destroy] [--auto-approve]
#
# This script runs Terraform in the `projects/secure-landing-zone/iac` folder.
# - By default it will `init`, `plan` and `apply` (local state bootstrap).
# - Use --migrate-backend after a successful apply to move local state into the
#   storage account and container created by the Terraform run.
# - Use --destroy to destroy resources instead of creating them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAC_DIR="$SCRIPT_DIR/../iac"

AUTO_APPROVE=false
MIGRATE_BACKEND=false
DESTROY=false

function usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --migrate-backend   After successful apply, re-init terraform with backend config and migrate state
  --destroy           Run 'terraform destroy' instead of apply
  --auto-approve      Pass -auto-approve to apply/destroy
  -h, --help          Show this help

Examples:
  # bootstrap infra (init, plan, apply)
  $0 --auto-approve

  # destroy resources
  $0 --destroy --auto-approve

  # bootstrap then migrate state to the created storage account
  $0 --auto-approve --migrate-backend
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --migrate-backend) MIGRATE_BACKEND=true; shift ;;
    --destroy) DESTROY=true; shift ;;
    --auto-approve) AUTO_APPROVE=true; shift ;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

# Ensure Azure CLI is available
if ! command -v az >/dev/null 2>&1; then
  echo "az CLI not found. Install Azure CLI and run 'az login' before using this script." >&2
  exit 1
fi

# Ensure Terraform is available
if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found. Install Terraform before using this script." >&2
  exit 1
fi

# Ensure logged in
if ! az account show >/dev/null 2>&1; then
  echo "Not logged into Azure. Run 'az login' to authenticate." >&2
  exit 1
fi

# Default TF_VAR values (override by exporting TF_VAR_* env vars before running)
: ${TF_VAR_resource_group_name:="slz-demo-rg"}
: ${TF_VAR_location:="eastus"}
: ${TF_VAR_name_prefix:="slz"}
: ${TF_VAR_backend_storage_account_prefix:="slzstate"}
: ${TF_VAR_backend_container_name:="tfstate"}

# Print effective variables
cat <<EOF
Running Terraform in: $IAC_DIR
Using variables:
  TF_VAR_resource_group_name=$TF_VAR_resource_group_name
  TF_VAR_location=$TF_VAR_location
  TF_VAR_name_prefix=$TF_VAR_name_prefix
  TF_VAR_backend_storage_account_prefix=$TF_VAR_backend_storage_account_prefix
  TF_VAR_backend_container_name=$TF_VAR_backend_container_name
EOF

pushd "$IAC_DIR" >/dev/null

# Format and validate
echo "-> Formatting Terraform files"
terraform fmt -check || terraform fmt

echo "-> Initializing Terraform"
terraform init

echo "-> Validating Terraform configuration"
terraform validate

if [ "$DESTROY" = true ]; then
  echo "-> Destroying infrastructure"
  if [ "$AUTO_APPROVE" = true ]; then
    terraform destroy -auto-approve
  else
    terraform destroy
  fi
  echo "Destroy complete. Exiting."
  popd >/dev/null
  exit 0
fi

# Plan
echo "-> Creating plan"
if [ "$AUTO_APPROVE" = true ]; then
  terraform plan -out=tfplan
  echo "-> Applying plan"
  terraform apply -auto-approve tfplan
else
  terraform plan -out=tfplan
  echo "To apply the plan run: terraform apply tfplan"
fi

# If migrate requested, re-init backend and migrate state
if [ "$MIGRATE_BACKEND" = true ]; then
  echo "-> Preparing backend migration"
  # Read outputs from last apply
  # Use -raw to get plain values
  backend_sa="$(terraform output -raw backend_storage_account_name 2>/dev/null || true)"
  backend_container="$(terraform output -raw backend_container_name 2>/dev/null || true)"

  if [ -z "$backend_sa" ] || [ -z "$backend_container" ]; then
    echo "Could not read backend outputs. Ensure apply completed and outputs exist." >&2
    popd >/dev/null
    exit 1
  fi

  echo "Backend storage account: $backend_sa"
  echo "Backend container: $backend_container"

  echo "-> Reinitializing terraform to use azurerm backend and migrating state"
  terraform init -migrate-state \
    -backend-config="storage_account_name=$backend_sa" \
    -backend-config="container_name=$backend_container" \
    -backend-config="key=secure-landing-zone.tfstate"

  echo "State migration complete. Remote backend active."
fi

# Show outputs
echo "-> Terraform outputs:"
terraform output

popd >/dev/null

echo "Done."
