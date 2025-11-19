import os
import logging
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.mgmt.monitor import MonitorManagementClient

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Remediation function invoked.')
    try:
        body = req.get_json()
    except:
        body = {}
    resource_id = body.get("resourceId")
    if not resource_id:
        return func.HttpResponse("Missing resourceId in body", status_code=400)

    subscription_id = os.environ.get("AZURE_SUBSCRIPTION_ID")
    workspace_id = os.environ.get("LOG_ANALYTICS_WORKSPACE_ID")
    if not subscription_id or not workspace_id:
        return func.HttpResponse("Missing env vars AZURE_SUBSCRIPTION_ID or LOG_ANALYTICS_WORKSPACE_ID", status_code=500)

    cred = DefaultAzureCredential()
    monitor = MonitorManagementClient(cred, subscription_id)
    name = "salz-auto-diag"

    diag = {
        "workspace_id": workspace_id,
        "logs": [
            {
                "category": "Administrative",
                "enabled": True
            }
        ],
        "metrics": []
    }

    try:
        monitor.diagnostic_settings.create_or_update(resource_id, name, diag)
    except Exception as e:
        logging.error(f"Failed to apply diagnostic settings: {e}")
        return func.HttpResponse(str(e), status_code=500)

    return func.HttpResponse(f"Remediated diagnostics for {resource_id}", status_code=200)
