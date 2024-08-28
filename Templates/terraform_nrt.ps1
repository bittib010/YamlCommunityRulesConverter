# Main Template starts here:
@"
resource "azurerm_sentinel_alert_rule_nrt" "nrt_$guid" {
  https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_nrt
  name                       = "$guid"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "$($row.Name)"
  severity                   = "$($row.Severity)"
  query                      = <<QUERY
$($row.Query)
QUERY
}
"@