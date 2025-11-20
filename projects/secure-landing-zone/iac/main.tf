resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.name_prefix}-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id
}

# --- Backend storage (used for state migration) ---
resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_account" "tfstate" {
  name                     = lower("${var.backend_storage_account_prefix}${random_string.storage_suffix.result}")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.backend_container_name
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

output "backend_storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "backend_container_name" {
  value = azurerm_storage_container.tfstate.name
}

# Storage account for Function App
resource "azurerm_storage_account" "function" {
  name                     = lower("${var.name_prefix}func${random_string.storage_suffix.result}")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_service_plan" "function_plan" {
  name                = "${var.name_prefix}-func-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "remediator" {
  name                       = "${var.name_prefix}-remediator"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_RUN_FROM_PACKAGE = "1"
    AZURE_SUBSCRIPTION_ID    = var.subscription_id != "" ? var.subscription_id : data.azurerm_subscription.primary.subscription_id
  }
}

data "azurerm_role_definition" "network_contributor" {
  name  = "Network Contributor"
  scope = data.azurerm_subscription.primary.id
}

resource "azurerm_role_assignment" "remediator_network_contrib" {
  scope              = azurerm_resource_group.rg.id
  role_definition_id = data.azurerm_role_definition.network_contributor.id
  principal_id       = azurerm_linux_function_app.remediator.identity[0].principal_id
}

# --- Policy definition and assignment (deny public IP) ---
resource "azurerm_policy_definition" "deny_public_ip" {
  name         = "deny-public-ip-creation"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny creation of public IP addresses (custom)"
  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/publicIPAddresses"
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
  metadata = jsonencode({
    category = "Network"
  })
}

resource "azurerm_subscription_policy_assignment" "deny_public_ip_assign" {
  name                 = "assign-deny-public-ip"
  policy_definition_id = azurerm_policy_definition.deny_public_ip.id
  subscription_id      = var.subscription_id != "" ? format("/subscriptions/%s", var.subscription_id) : data.azurerm_subscription.primary.id
}

data "azurerm_subscription" "primary" {}
