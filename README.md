# Secure Landing Zone Orchestrator

This project is a starter MVP for an automated Secure Landing Zone on Azure. It demonstrates GitOps/IaC provisioning, Azure Policy enforcement, and an automated remediation stub (Azure Function). Use it as a template to expand into a production-ready solution.

Quick overview
- IaC: Terraform modules to provision a baseline (Resource Group, Log Analytics)
- Policy: Sample Azure Policy definition (deny public IPs)
- Automation: Azure Function HTTP-triggered remediation stub
- CI: GitHub Actions workflow that runs `terraform fmt`, `terraform init`, `terraform plan`

Prerequisites
- Azure subscription with permissions to create resource groups and policy assignments
- Azure CLI installed and `az login` performed
- Terraform >= 1.0 installed
- (Optional) GitHub repo linked for CI/CD

Quick deploy (demo)
1. Open PowerShell and authenticate:

```powershell
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>
```

2. Initialize Terraform and apply (demo uses local backend by default):

```powershell
cd projects/secure-landing-zone/iac
terraform init
terraform apply -auto-approve
```

3. Note outputs (resource group name, workspace id).
4. Deploy the Azure Function (see `projects/secure-landing-zone/functions/README.md` for a simple guide), or test the function locally via `func` core tools.

Verification
- Confirm the resource group and Log Analytics workspace exist in the Azure Portal.
- Review the GitHub Actions workflow runs in `.github/workflows/terraform.yml` after pushing.
- Use the demo script to trigger a test event against the Function and watch logs.

Next steps
- Replace the remediation stub with concrete Azure SDK-based changes (e.g., detach Public IP or apply missing tags) using Managed Identity.
- Add policy assignment via Terraform and wire Policy events into Event Grid to trigger the Function.
- Expand IaC modules to create VNet, NSG, Key Vault and sample workloads to test remediation flows.

Deploying the Function App (automated remediation)
------------------------------------------------
This repo now includes:
- Terraform to create an Azure Function App with a system-assigned Managed Identity and grant it `Network Contributor` on the landing zone Resource Group.
- A Python Function in `projects/secure-landing-zone/functions/auto_remediate` that will delete a public IP resource when POSTed a JSON payload containing `resourceId`.

Local/manual deploy (quick):
1. After running `terraform apply` (the function app resources are created), build a zip from the function folder:

```powershell
cd projects/secure-landing-zone/functions/auto_remediate
python -m pip install --upgrade pip
pip install -r requirements.txt --target ./package
(cd package; zip -r ../functionapp.zip .)
zip -g functionapp.zip __init__.py function.json
```

2. Deploy the zip using Azure CLI (replace placeholders):

```powershell
az functionapp deployment source config-zip --resource-group <rg> --name <function-name> --src functionapp.zip
```

3. Test the function (replace URL printed in Azure Portal):

```powershell
$payload = @{resourceId = '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/publicIPAddresses/<pip-name>'} | ConvertTo-Json
Invoke-RestMethod -Uri <function-url> -Method Post -Body $payload -ContentType 'application/json'
```

GitHub Actions deploy:
- The workflow `projects/secure-landing-zone/.github/workflows/deploy_function.yml` zips and deploys the Function. It requires a GitHub secret `AZURE_CREDENTIALS` containing a Service Principal JSON and `FUNCTION_APP_NAME` with the Function App name.

Security/permissions note:
- The Function's Managed Identity is granted `Network Contributor` on the Resource Group by Terraform to allow it to delete Public IPs. Only grant the minimal scope/role required in production.

Backend & policy migration notes
--------------------------------
This repo includes Terraform resources to create a storage account and container intended to be used as an `azurerm` backend for remote state. Because Terraform needs the storage container to exist before you configure the backend, follow these steps to bootstrap and migrate state:

1. Initialize and apply using local state to create the storage account + container:

```powershell
cd projects/secure-landing-zone/iac
terraform init
terraform apply -auto-approve
```

2. Note the output values `backend_storage_account_name` and `backend_container_name`.

3. Reconfigure the backend to use the new storage account. Create a file `backend.tfvars` with:

```text
resource_group_name=<the-resource-group-created>
storage_account_name=<backend_storage_account_name>
container_name=<backend_container_name>
key=secure-landing-zone.tfstate
```

4. Reinitialize Terraform with the backend config and migrate state (this will prompt to copy local state to remote):

```powershell
terraform init -migrate-state -backend-config=storage_account_name=<backend_storage_account_name> -backend-config=container_name=<backend_container_name> -backend-config=key=secure-landing-zone.tfstate
```

5. After migration, future runs will use the remote `azurerm` backend.

Policy assignment
-----------------
This project now creates a custom Policy Definition and assigns it at subscription scope (if `subscription_id` variable is set) or to the current subscription. If you plan to run this in a shared environment, confirm the subscription scope before applying.
