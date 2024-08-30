# https://learn.microsoft.com/en-us/azure/sentinel/create-nrt-rules?tabs=azure-portal
# Prepare Description
# Add description format if available
if ($row.Description) {
    $description = $row.Description
    $description = $description.Trim('"')  # Strip first and last double quotes
    $description = $description.Trim("'")  # Strip first and last double quotes

    # Now perform the replacements
    $description = $description -replace "`n|`r|'", ""
    $description = $description -replace "\\", "\\"
    $description = $description -replace "`"", "\`"" 
}

if ($row.Query) {
    $query = $row.Query
    $query = $query.Trim('"')  # Strip first and last double quotes
    $query = $query.Trim("'")  # Strip first and last double quotes

    # Now perform the replacements
    $query = $query -replace "`n", "\n"
    $query = $query -replace "`r", "\r"
    $query = $query -replace "\\d", "\\d"
    $query = $query -replace "\\[", "\\["
    $query = $query -replace "\\.", "\\."
    # $query = $query -replace "\\", "\\"
    $query = $query -replace "`"", "\`"" 
}


# Main template starts here
@"
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "workspace": {
        "type": "String"
      }
    },
    "resources": [
      {
        "id": "[concat(resourceId('Microsoft.OperationalInsights/workspaces/providers', parameters('workspace'), 'Microsoft.SecurityInsights'),'/alertRules/4a4364e4-bd26-46f6-a040-ab14860275f8')]",
        "name": "[concat(parameters('workspace'),'/Microsoft.SecurityInsights/4a4364e4-bd26-46f6-a040-ab14860275f8')]",
        "type": "Microsoft.OperationalInsights/workspaces/providers/alertRules",
        "kind": "NRT",
        "apiVersion": "2022-11-01-preview",
        "properties": {
          "displayName": "$($row.Name)",
          "description": "$description",
          "severity": "$($row.Severity)",
          "enabled": true,
          "query": "$query)",
          "suppressionDuration": "PT1H",
          "suppressionEnabled": false,
          "tactics": [
            "CredentialAccess"
          ],
          "alertRuleTemplateName": "$($row.Id)",
          "incidentConfiguration": {
            "groupingConfiguration": {
              "matchingMethod": "AllEntities",
              "groupByEntities": [],
              "groupByAlertDetails": [],
              "lookbackDuration": "PT5H",
              "groupByCustomDetails": [],
              "reopenClosedIncident": false,
              "enabled": false
            },
            "createIncident": true
          },
          "eventGroupingSettings": {
            "aggregationKind": "SingleAlert"
          },
          "customDetails": null,
          "entityMappings": [
            {
              "fieldMappings": [
                {
                  "identifier": "Name",
                  "columnName": "Name"
                },
                {
                  "identifier": "UPNSuffix",
                  "columnName": "UPNSuffix"
                }
              ],
              "entityType": "Account"
            },
            {
              "fieldMappings": [
                {
                  "identifier": "Address",
                  "columnName": "InitiatingIpAddress"
                }
              ],
              "entityType": "IP"
            }
          ],
          "templateVersion": "1.0.1"
        }
      }
    ]
  }
"@