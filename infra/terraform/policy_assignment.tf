data "azurerm_subscription" "current" {}

resource "azurerm_policy_definition" "enable_diag" {
  name         = "salz-enable-diagnostics"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Ensure diagnostic settings to send logs to Log Analytics"
  description  = "Deploy diagnostic settings when missing"
  policy_rule  = file("${path.module}/../../policies/diag-deployifnotexists.json")
}

resource "azurerm_policy_assignment" "assign_enable_diag" {
  name                 = "salz-assign-enable-diagnostics"
  scope                = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.enable_diag.id

  parameters = jsonencode({
    logAnalytics = {
      value = azurerm_log_analytics_workspace.la.id
    }
  })
}
