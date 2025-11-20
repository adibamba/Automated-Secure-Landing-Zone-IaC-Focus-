param(
    [switch]$MigrateBackend,
    [switch]$Destroy,
    [switch]$AutoApprove
)

<#
.SYNOPSIS
  PowerShell wrapper to run Terraform for the Secure Landing Zone project.

USAGE
  From the `projects/secure-landing-zone/scripts` folder run:
    .\terraform_deploy.ps1 -AutoApprove
    .\terraform_deploy.ps1 -MigrateBackend -AutoApprove
    .\terraform_deploy.ps1 -Destroy -AutoApprove

This script expects Terraform and az CLI to be in PATH and you to be logged in (az login).
#>

Set-StrictMode -Version Latest
Write-Host "Terraform deploy script (PowerShell)" -ForegroundColor Cyan

function Ensure-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Error "$Name not found in PATH. Install it and re-run the script."
        exit 1
    }
}

Ensure-Command -Name terraform
Ensure-Command -Name az

try {
    az account show > $null 2>&1
} catch {
    Write-Error "Not logged into Azure. Run 'az login' and try again."; exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$iacDir = Join-Path $scriptDir '..\iac' | Resolve-Path -Relative

Write-Host "Running terraform in: $iacDir"

Push-Location $iacDir

Write-Host "Formatting Terraform files..."
terraform fmt -check | Out-Null 2>&1
if ($LASTEXITCODE -ne 0) {
    terraform fmt
}

Write-Host "Initializing Terraform..."
terraform init

Write-Host "Validating Terraform configuration..."
terraform validate
if ($LASTEXITCODE -ne 0) { Write-Error "Terraform validate failed"; Pop-Location; exit 1 }

if ($Destroy) {
    Write-Host "Destroying infrastructure..."
    if ($AutoApprove) { terraform destroy -auto-approve } else { terraform destroy }
    Pop-Location; exit 0
}

Write-Host "Planning..."
terraform plan -out=tfplan
if ($AutoApprove) {
    Write-Host "Applying plan..."
    terraform apply -auto-approve tfplan
} else {
    Write-Host "Plan written to tfplan. Run 'terraform apply tfplan' to apply."
}

if ($MigrateBackend) {
    Write-Host "Preparing backend migration..."
    $backendSA = terraform output -raw backend_storage_account_name
    $backendContainer = terraform output -raw backend_container_name
    if (-not $backendSA -or -not $backendContainer) {
        Write-Error "Could not read backend outputs. Ensure apply completed and outputs exist."; Pop-Location; exit 1
    }
    Write-Host "Reinitializing terraform to use remote backend and migrating state..."
    terraform init -migrate-state -backend-config="storage_account_name=$backendSA" -backend-config="container_name=$backendContainer" -backend-config="key=secure-landing-zone.tfstate"
    Write-Host "State migration complete."
}

Write-Host "Terraform outputs:" -ForegroundColor Green
terraform output

Pop-Location
Write-Host "Done."