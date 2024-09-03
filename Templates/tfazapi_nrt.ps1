# https://learn.microsoft.com/en-us/azure/templates/microsoft.securityinsights/alertrules?pivots=deployment-language-terraform
# https://learn.microsoft.com/en-us/azure/templates/microsoft.securityinsights/2022-01-01-preview/alertrules?pivots=deployment-language-terraform
# Main Template starts here:
@"
resource "azapi_resource" "nrt_$guid" {
  type      = "Microsoft.SecurityInsights/alertRules@2022-01-01-preview"
  name      = "$guid"
  parent_id = var.log_analytics_workspace_id

  body = jsonencode({
    kind       = "NRT"
    properties = {
      displayName        = "$($row.Name)"
      description        = "$($row.Description)"
      severity           = "$($row.Severity)"
      query              = "$($row.Query)"
      queryFrequency     = "$($row.QueryFrequency)"
      queryPeriod        = "$($row.QueryPeriod)"
      triggerOperator    = "$($row.TriggerOperator)"
      triggerThreshold   = $($row.TriggerThreshold)
      suppressionEnabled = $($row.SuppressionEnabled)
      tactics            = ["InitialAccess", "Execution"]$($row.Tactics)
      enabled            = true
    }
  })
}

"@