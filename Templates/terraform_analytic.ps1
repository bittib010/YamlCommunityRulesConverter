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
        $parts = $mapping -split ': '

        # Start entity_mapping block
        $entityMappings += "`tentity_mapping {`n"
        $entityMappings += "`t`tentity_type = `"$($parts[0])`"`n"

        # Check if fieldMappings exist
        if ($parts[1]) {
            $fieldMappingsArray = $parts[1] -split ', '
            foreach ($fieldMapping in $fieldMappingsArray) {
                $fieldParts = $fieldMapping -split '='
                $columnName = $fieldParts[0].Trim()
                $identifier = $fieldParts[1].Trim()

                $entityMappings += "`t`tfield_mapping {`n"
                $entityMappings += "`t`t`t`tcolumn_name = `"$columnName`"`n"
                $entityMappings += "`t`t`t`tidentifier  = `"$identifier`"`n"
                $entityMappings += "`t`t}`n"
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
    $customDetails = ($customDetailsArray | ForEach-Object { "'$_'" }) -join ', '
    $customDetailsSection = "  custom_details             = {$customDetails}`n"
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

$customDetailsSection  # This line is conditionally included if custom details exist
  description                = "$description" 
  enabled                    = true  // Will later be used to set based on a column controlled by the user.
  entity_mapping             = $entityMappings
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
