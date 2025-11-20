# Execution Guide: Secure Landing Zone Project

This guide provides step-by-step instructions to deploy, test, and destroy the Secure Landing Zone project using the provided scripts.

**Prerequisites:**
- Azure CLI (`az`) installed and logged in (`az login`).
- Terraform installed.
- Python 3.10+ installed (for packaging the function).
- `zip` utility installed (standard in Git Bash).

**Working Directory:**
All commands below assume you are in the `projects/secure-landing-zone/scripts` directory.

```bash
cd ~/Documents/Automated-Secure-Landing-Zone-IaC-Focus-/projects/secure-landing-zone/scripts
```

---

## Step 1: Deploy Infrastructure

1.  **Make the script executable** (if not already):
    ```bash
    chmod +x terraform_deploy.sh
    ```

2.  **Run the deployment script**:
    This initializes Terraform and applies the configuration to create the Resource Group, Function App, Storage Accounts, and Log Analytics Workspace.
    ```bash
    ./terraform_deploy.sh --auto-approve
    ```

3.  **Note the Outputs**:
    At the end, you will see outputs like `resource_group_name` and the function app name (e.g., `slz-remediator`). You will need these.

---

## Step 2: Deploy the Function Code

The infrastructure is ready, but the Function App is empty. We need to package and deploy the Python code.

1.  **Navigate to the function directory**:
    ```bash
    cd ../functions/auto_remediate
    ```

2.  **Install dependencies and Zip**:
    ```bash
    # Create a package folder and install requirements
    pip install -r requirements.txt --target ./package

    # Zip the dependencies
    cd package
    zip -r ../functionapp.zip .
    cd ..

    # Add the function code to the zip
    zip -g functionapp.zip __init__.py function.json
    ```

3.  **Deploy to Azure**:
    Replace `<function-app-name>` with the name from Step 1 outputs (e.g., `slz-remediator`).
    Replace `<resource-group-name>` with the RG name (default: `slz-demo-rg`).

    ```bash
    # Example names - REPLACE with yours
    FUNC_APP_NAME="slz-remediator" 
    RG_NAME="slz-demo-rg"

    az functionapp deployment source config-zip --resource-group $RG_NAME --name $FUNC_APP_NAME --src functionapp.zip
    ```

4.  **Return to scripts directory**:
    ```bash
    cd ../../scripts
    ```

---

## Step 3: Test the Remediation

We will create a Public IP (which is against policy) and trigger the function to delete it.

1.  **Create a Test Public IP**:
    ```bash
    TEST_PIP_NAME="test-pip-delete-me"
    RG_NAME="slz-demo-rg"

    az network public-ip create --name $TEST_PIP_NAME --resource-group $RG_NAME --allocation-method Static
    ```

2.  **Get the Public IP Resource ID**:
    ```bash
    PIP_ID=$(az network public-ip show --name $TEST_PIP_NAME --resource-group $RG_NAME --query id -o tsv)
    echo "Created Public IP: $PIP_ID"
    ```

3.  **Get the Function URL**:
    ```bash
    FUNC_APP_NAME="slz-remediator" # Replace if different
    
    # Get the function key
    FUNC_KEY=$(az functionapp function keys list --resource-group $RG_NAME --name $FUNC_APP_NAME --function-name auto_remediate --query 'default' -o tsv)
    
    # Construct URL
    FUNC_URL="https://$FUNC_APP_NAME.azurewebsites.net/api/auto_remediate?code=$FUNC_KEY"
    echo "Function URL: $FUNC_URL"
    ```

4.  **Invoke the Function**:
    ```bash
    curl -X POST -H "Content-Type: application/json" -d "{\"resourceId\": \"$PIP_ID\"}" "$FUNC_URL"
    ```

5.  **Verify Deletion**:
    Check if the Public IP still exists. It should be gone (or return an error).
    ```bash
    az network public-ip show --name $TEST_PIP_NAME --resource-group $RG_NAME
    ```

---

## Step 4: Cleanup

Destroy all resources to avoid costs.

```bash
./terraform_deploy.sh --destroy --auto-approve
```
