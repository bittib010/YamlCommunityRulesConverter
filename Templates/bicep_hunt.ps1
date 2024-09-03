# Main Template starts here:
@"
param logAnalyticsWorkspaceId string = var.log_analytics_workspace_id
param queryName string = $guid
param displayName string = $($row.Name)
param category string = "Security"
param query string = $($row.Query)
param version int = 2

resource huntingQuery 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: queryName
  parent: resource(logAnalyticsWorkspaceId)
  properties: {
    displayName: displayName
    category: category
    query: query
    version: version
  }
}

"@