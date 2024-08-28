resource "azurerm_sentinel_alert_rule_nrt" "{{GUID}}" {
  https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_nrt
  name                       = "{{GUID}}"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "{{Name}}"
  severity                   = "{{Severity}}"
  query                      = <<QUERY
{{Query}}
QUERY
}