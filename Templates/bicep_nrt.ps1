# Main Template starts here:
@"
param logAnalyticsWorkspaceId string = var.log_analytics_workspace_id
param ruleName string = $guid
param ruleDisplayName string = $($row.Name)
param ruleDescription string = $($row.Description)
param ruleSeverity string = $($row.Severity)
param ruleQuery string = $($row.Query)
param queryFrequency string = $($row.QueryFrequency)
param queryPeriod string = $($row.QueryPeriod)
param triggerOperator string = $($row.TriggerOperator)
param triggerThreshold int = $($row.TriggerThreshold)
param suppressionEnabled bool = $($row.SuppressionEnabled)
param tactics array = $($row.Tactics)

resource nrtRule 'Microsoft.SecurityInsights/alertRules@2022-01-01-preview' = {
  name: ruleName
  parent: resource(logAnalyticsWorkspaceId)
  properties: {
    kind: 'NRT'
    displayName: ruleDisplayName
    description: ruleDescription
    severity: ruleSeverity
    query: ruleQuery
    queryFrequency: queryFrequency
    queryPeriod: queryPeriod
    triggerOperator: triggerOperator
    triggerThreshold: triggerThreshold
    suppressionEnabled: suppressionEnabled
    tactics: tactics
    enabled: true
  }
}

"@