#################################################
# Prepare AlertDetailsOverride for Scheduled Rule
#################################################
$AlertDetailsOverride = $row.AlertDetailsOverride
$AlertDetailsOverrideJson = ConvertFrom-Json $AlertDetailsOverride
$alertDescriptionFormat = $AlertDetailsOverrideJson.alertDescriptionFormat -replace '"', '\"' -replace '\n', '\n' -replace '\r', '\r' -replace "'", "\'"
$alertSeverityColumnName = $AlertDetailsOverrideJson.alertSeverity -replace '"', '\"' -replace "'", "\'"
$alertnameFormat = $AlertDetailsOverrideJson.alertnameFormat -replace '"', '\"'  -replace "'", "\'"
# Convert alertDynamicProperties to the desired format
$alertDynamicProperties = @()
foreach ($property in $AlertDetailsOverrideJson.alertDynamicProperties) {
  $alertDynamicProperties += "{
    alertProperty: '$($property.alertProperty)'
    value: '$($property.value)'
  }
    "
}
$alertDynamicProperties = $alertDynamicProperties -join ""
$alertDynamicProperties = "[$alertDynamicProperties]"


#######################
# Prepare customdetails
#######################
$customDetails = $row.CustomDetails
# if customDetails is empty, skip it
if ($customDetails -ne $null -and $customDetails -ne "") {
  $customDetails = $customDetails -split ',' | ForEach-Object {
    $key, $value = $_ -split ':'
    $key = $key.Trim()
    if ($value -eq $null) {
      $value = ""
    } else {
      $value = $value.Trim()
    }
    # escape single quotes in value
    $value = $value -replace "'", "''"
    # escape single quotes in key
    $key = $key -replace "'", "''"
    # return key value pair
    "$key : '$value'"
  }
  $customDetails = $customDetails -join "`n`t`t"
}

#######################
# Prepare description
#######################

$description = $row.Description -replace '"', '\"' -replace "'", "\'" -replace '\n', '\n' -replace '\r', '\r'



$alertTactics = $AlertDetailsOverrideJson.alertTactics -replace '"', '\"'

# Main Template starts here:
@"
resource scheduledRule 'Microsoft.SecurityInsights/alertRules@2023-02-01-preview' = {
  // name: 'string'
  scope: resourceSymbolicName
  // etag: 'string'
  kind: 'Scheduled'
  properties: {
    alertDetailsOverride: {
      alertDescriptionFormat: '$alertDescriptionFormat'
      alertDisplayNameFormat: '$alertnameFormat'
      alertDynamicProperties: $alertDynamicProperties
      alertSeverityColumnName: '$alertSeverityColumnName'
      alertTacticsColumnName: '$alertTactics'
    }
    alertRuleTemplateName: '$($row.Id)'
    customDetails: {
    $customDetails
    }
    description: '$description'
    displayName: '$($row.Name)'
    enabled: true
    entityMappings: [
      {
        entityType: 'string'
        fieldMappings: [
          {
            columnName: 'string'
            identifier: 'string'
          }
        ]
      }
    ]
    eventGroupingSettings: {
      aggregationKind: 'string'
    }
    incidentConfiguration: {
      createIncident: bool
      groupingConfiguration: {
        enabled: bool
        groupByAlertDetails: [
          'string'
        ]
        groupByCustomDetails: [
          'string'
        ]
        groupByEntities: [
          'string'
        ]
        lookbackDuration: 'string'
        matchingMethod: 'string'
        reopenClosedIncident: bool
      }
    }
    query: 'string'
    queryFrequency: 'string'
    queryPeriod: 'string'
    sentinelEntitiesMappings: [
      {
        columnName: 'string'
      }
    ]
    severity: 'string'
    suppressionDuration: 'string'
    suppressionEnabled: bool
    tactics: [
      'string'
    ]
    techniques: [
      'string'
    ]
    templateVersion: 'string'
    triggerOperator: 'string'
    triggerThreshold: int
  }
}

"@