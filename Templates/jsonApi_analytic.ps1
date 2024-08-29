# https://learn.microsoft.com/en-us/rest/api/securityinsights/alert-rules/create-or-update?view=rest-securityinsights-2024-03-01&tabs=HTTP#creates-or-updates-a-scheduled-alert-rule.

# Main Template starts here:
@"
PUT https://management.azure.com/subscriptions/d0cfe6b2-9ac0-4464-9919-dccaee2e48c0/resourceGroups/myRg/providers/Microsoft.OperationalInsights/workspaces/myWorkspace/providers/Microsoft.SecurityInsights/alertRules/73e01a99-5cd7-4139-a149-9f2736ff2ab5?api-version=2024-03-01

{
  "kind": "Scheduled",
  "etag": "\"0300bf09-0000-0000-0000-5c37296e0000\"",
  "properties": {
    "displayName": "My scheduled rule",
    "description": "An example for a scheduled rule",
    "severity": "High",
    "enabled": true,
    "tactics": [
      "Persistence",
      "LateralMovement"
    ],
    "query": "Heartbeat",
    "queryFrequency": "PT1H",
    "queryPeriod": "P2DT1H30M",
    "triggerOperator": "GreaterThan",
    "triggerThreshold": 0,
    "suppressionDuration": "PT1H",
    "suppressionEnabled": false,
    "eventGroupingSettings": {
      "aggregationKind": "AlertPerResult"
    },
    "customDetails": {
      "OperatingSystemName": "OSName",
      "OperatingSystemType": "OSType"
    },
    "entityMappings": [
      {
        "entityType": "Host",
        "fieldMappings": [
          {
            "identifier": "FullName",
            "columnName": "Computer"
          }
        ]
      },
      {
        "entityType": "IP",
        "fieldMappings": [
          {
            "identifier": "Address",
            "columnName": "ComputerIP"
          }
        ]
      }
    ],
    "alertDetailsOverride": {
      "alertDisplayNameFormat": "Alert from {{Computer}}",
      "alertDescriptionFormat": "Suspicious activity was made by {{ComputerIP}}",
      "alertDynamicProperties": [
        {
          "alertProperty": "ProductComponentName",
          "value": "ProductComponentNameCustomColumn"
        },
        {
          "alertProperty": "ProductName",
          "value": "ProductNameCustomColumn"
        },
        {
          "alertProperty": "AlertLink",
          "value": "Link"
        }
      ]
    },
    "incidentConfiguration": {
      "createIncident": true,
      "groupingConfiguration": {
        "enabled": true,
        "reopenClosedIncident": false,
        "lookbackDuration": "PT5H",
        "matchingMethod": "Selected",
        "groupByEntities": [
          "Host"
        ],
        "groupByAlertDetails": [
          "DisplayName"
        ],
        "groupByCustomDetails": [
          "OperatingSystemType",
          "OperatingSystemName"
        ]
      }
    }
  }
}
"@