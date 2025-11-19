output "rg_name" {
  value = azurerm_resource_group.core.name
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.la.id
}
