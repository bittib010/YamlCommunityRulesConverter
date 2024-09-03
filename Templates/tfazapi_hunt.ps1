# https://learn.microsoft.com/en-us/azure/templates/microsoft.operationalinsights/workspaces/savedsearches?pivots=deployment-language-terraform
# Main Template starts here:
@"
resource "azapi_resource" "hunt_$guid" {
  type      = "Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01"
  name      = "$guid"
  parent_id = "your_workspace_resource_id" // Add your workspace resource id

  body = jsonencode({
    properties = {
      category     = "Hunting Queries"
      displayName  = "$($row.Name)"
      query        = "$($row.Query)"
      version      = 2
      tags         = ["Hunting Queries"]
    }
  })
}

"@