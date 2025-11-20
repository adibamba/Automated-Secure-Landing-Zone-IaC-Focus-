import logging
import os
import json

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.mgmt.network import NetworkManagementClient


# Real remediation: if given a public IP resource id, delete that public IP using
# the Function App's system-assigned Managed Identity (requires Network Contributor).

def parse_resource_id(resource_id: str):
    # Very small parser expecting IDs like:
    # /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/publicIPAddresses/{name}
    parts = [p for p in resource_id.split('/') if p]
    d = {}
    try:
        for i, p in enumerate(parts):
            if p.lower() == 'subscriptions':
                d['subscription'] = parts[i + 1]
            if p.lower() == 'resourcegroups':
                d['resource_group'] = parts[i + 1]
            if p.lower() == 'publicipaddresses':
                d['public_ip_name'] = parts[i + 1]
    except Exception:
        return {}
    return d


async def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Auto-remediate function received a request.')

    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse(json.dumps({'error': 'invalid json'}), status_code=400, mimetype='application/json')

    logging.info('Event payload: %s', json.dumps(body))

    resource_id = body.get('resourceId') or body.get('resource_id') or body.get('resource')
    if not resource_id:
        return func.HttpResponse(json.dumps({'error': 'resourceId missing'}), status_code=400, mimetype='application/json')

    if 'Microsoft.Network/publicIPAddresses' not in resource_id:
        return func.HttpResponse(json.dumps({'status': 'ignored', 'reason': 'not a public IP resource'}), status_code=200, mimetype='application/json')

    parts = parse_resource_id(resource_id)
    if not parts.get('resource_group') or not parts.get('public_ip_name'):
        return func.HttpResponse(json.dumps({'error': 'could not parse resource id'}), status_code=400, mimetype='application/json')

    subscription = os.environ.get('AZURE_SUBSCRIPTION_ID')
    if not subscription:
        return func.HttpResponse(json.dumps({'error': 'missing AZURE_SUBSCRIPTION_ID app setting'}), status_code=500, mimetype='application/json')

    try:
        credential = DefaultAzureCredential()
        net_client = NetworkManagementClient(credential, subscription)

        rg = parts['resource_group']
        pip_name = parts['public_ip_name']

        logging.info('Attempting to delete public IP %s in %s', pip_name, rg)
        poller = net_client.public_ip_addresses.begin_delete(rg, pip_name)
        poller.wait()

        logging.warning('Deleted public IP %s in %s', pip_name, rg)
        return func.HttpResponse(json.dumps({'status': 'deleted', 'resource': resource_id}), status_code=200, mimetype='application/json')

    except Exception as ex:
        logging.exception('Remediation failed: %s', ex)
        return func.HttpResponse(json.dumps({'status': 'error', 'message': str(ex)}), status_code=500, mimetype='application/json')
