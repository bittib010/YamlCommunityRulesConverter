# Prepare tactics
$tacticsArray = $row.Tactics -split ', '
$tactics = ($tacticsArray | ForEach-Object { "`"$_`"" }) -join ', '

# Prepare Techniques
$techniquesArray = $row.RelevantTechniques -split ', '
$techniques = ($techniquesArray | ForEach-Object { "`"$($_ -split '\.')`"" }) -join ', '

# Prepare Entity Mappings
$entityMappingsArray = $row.EntityMappings -split '; '

$entityMappings = ""
if ($entityMappingsArray -and $entityMappingsArray.Length -gt 0) {
    foreach ($mapping in $entityMappingsArray) {
        $mappingParts = $mapping -split ', fieldMappings: '

        # Extract the entity type
        $entityType = $mappingParts[0] -replace 'entityType: ', ''

        # Start entity_mapping block
        $entityMappings += "entity_mapping {`n"
        $entityMappings += "entity_type = `"$entityType`"`n"

        # Process field mappings if they exist
        if ($mappingParts.Length -gt 1) {
            $fieldMappings = $mappingParts[1]
            $fieldMappingsArray = $fieldMappings -split ',\s*'  # Split on comma followed by any whitespace
            
            foreach ($fieldMapping in $fieldMappingsArray) {
                $fieldParts = $fieldMapping -split ':'

                if ($fieldParts.Length -eq 2) {
                    $identifier = $fieldParts[0].Trim()
                    $columnName = $fieldParts[1].Trim()

                    $entityMappings += "field_mapping {`n"
                    $entityMappings += "identifier  = `"$identifier`"`n"
                    $entityMappings += "column_name = `"$columnName`"`n"
                    $entityMappings += "}`n"
                } else {
                    Write-Host "Warning: Malformed field mapping encountered: $fieldMapping"
                }
            }
        }

        # End entity_mapping block
        $entityMappings += "`t}`n"
    }
} else {
    $entityMappings = "{}"
}

# Prepare Description to not be printed on multiple lines.
$description = $row.Description
$description = $description -replace "`n|`r|'", ""
$description = $description -replace "\\", "\\"
$description = $description -replace "`"", "\`"" 

$query = $row.Query
$queryPeriod = $row.QueryPeriod
$queryFrequency = $row.QueryFrequency
$TriggerThreshold = $row.TriggerThreshold
$TriggerOperator = $row.TriggerOperator

# Prepare custom details if available
$customDetailsSection = ""
if ($row.CustomDetails) {
    $customDetailsArray = $row.CustomDetails -split ', '
    $customDetails = @()

    foreach ($detail in $customDetailsArray) {
        $keyValue = $detail -split ': '
        $key = $keyValue[0].Trim()
        $value = $keyValue[1].Trim()
        $customDetails += "$key = `"$value`""
    }

    $customDetailsSection = "  custom_details = {`n    " + ($customDetails -join "`n    ") + "`n  }`n"
}


# Main Template starts here:
@"
resource "azurerm_sentinel_alert_rule_scheduled" "ar_$guid" {
  // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_scheduled
  name                       = "$guid"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "$($row.Name)"
  severity                   = "$($row.Severity)"

  tactics                    = [$tactics] 
  techniques                 = [$techniques]
  alert_details_override     = {}
  alert_rule_template_guid   = "$($row.Id)"
  alert_rule_template_version = "$($row.Version)"

  trigger_threshold          = $TriggerThreshold

  $customDetailsSection  
  description                = "$description" 
  enabled                    = true  // Will later be used to set based on a column controlled by the user.
  $entityMappings
  event_grouping {
    aggregation_method       = "AlertPerResult"
  }
  incident {
    create_incident_enabled  = true
    grouping {
      enabled                = true
      entity_matching_method = "Selected"
      lookback_duration      = "PT8H"
      by_entities            = ["Account"]
    }
  }
  query_frequency            = "$queryFrequency"
  query_period               = "$queryPeriod"
  query                      = <<QUERY
$query
QUERY
}
"@
