resource "azurerm_resource_group" "core" {
  name     = var.rg_name
  location = var.location
  tags = {
    project = "SALZ"
    owner   = "you@example.com"
  }
}

resource "azurerm_log_analytics_workspace" "la" {
  name                = var.log_analytics_name
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "random_id" "sa" {
  byte_length = 4
}

resource "azurerm_storage_account" "diagnostics" {
  name                     = lower(substr("saldia${random_id.sa.hex}",0,24))
  resource_group_name      = azurerm_resource_group.core.name
  location                 = azurerm_resource_group.core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
