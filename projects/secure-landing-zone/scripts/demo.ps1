# Demo script for Secure Landing Zone (PowerShell)
# Run from repository root on Windows PowerShell after installing Terraform and Azure CLI

param(
  [string]$SubscriptionId
)

if (-not $SubscriptionId) {
  Write-Host "Usage: .\demo.ps1 -SubscriptionId <id>"
  exit 1
}

# Login & set subscription
az login
az account set --subscription $SubscriptionId

# Navigate to IaC
Push-Location projects/secure-landing-zone/iac

# Initialize and apply Terraform (local backend unless configured)
terraform init
terraform apply -auto-approve

Pop-Location

Write-Host "Terraform apply complete. Check Azure Portal for resource group 'slz-demo-rg' or configured name."

# Test Function (if deployed) - sample HTTP POST
$funcUrl = Read-Host 'Enter Function URL to test (press Enter to skip)'
if ($funcUrl -ne '') {
  $payload = @{test = 'simulated_event'; resource = 'Microsoft.Network/publicIPAddresses'} | ConvertTo-Json
  Invoke-RestMethod -Uri $funcUrl -Method Post -Body $payload -ContentType 'application/json' | ConvertTo-Json
}

Write-Host "\nIf you want to migrate state to the new storage account created by this run, follow these steps:" -ForegroundColor Yellow
Write-Host "1) Note outputs: backend_storage_account_name and backend_container_name" -ForegroundColor Yellow
Write-Host "2) Re-run terraform init with backend config to migrate state (example):" -ForegroundColor Yellow
Write-Host "   terraform init -migrate-state -backend-config=storage_account_name=<name> -backend-config=container_name=<container> -backend-config=key=secure-landing-zone.tfstate" -ForegroundColor Yellow
