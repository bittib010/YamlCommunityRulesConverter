# Prepare tactics
$tacticsOut = ""
if ($row.Tactics) {
    $tacticsArray = $row.Tactics -split ', '
    $tactics = ($tacticsArray | ForEach-Object { "`"$_`"" }) -join ', '
    $tacticsOut = "tactics                    = [$tactics] "
}

# Prepare Techniques
$techniquesOut = ""
if ($row.RelevantTechniques) {
    $techniquesArray = $row.RelevantTechniques -split ', '
    $techniques = ($techniquesArray | ForEach-Object { "`"$($_ -split '\.')`"" }) -join ', '
    $techniquesOut = "techniques                 = [$techniques]"
}

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
                }
                else {
                    Write-Host "Warning: Malformed field mapping encountered: $fieldMapping"
                }
            }
        }

        # End entity_mapping block
        $entityMappings += "`t}`n"
    }
}

# Prepare Description to not be printed on multiple lines.
$description = $row.Description
$description = $description -replace "`n|`r|'", ""
$description = $description -replace "\\", "\\"
$description = $description -replace "`"", "\`"" 

# Function to convert time to ISO 8601 duration format
function Convert-ToISO8601Duration {
    param (
        [string]$timeValue
    )

    if ($timeValue -match '(\d+)([hmd])') {
        $value = $matches[1]
        $unit = $matches[2]

        switch ($unit) {
            'h' { return "PT${value}H" } # Hours
            'm' { return "PT${value}M" } # Minutes
            'd' { return "P${value}D" }  # Days
            default { return $timeValue } # In case it's already in ISO 8601 or unrecognized
        }
    }
    else {
        return $timeValue # If the format doesn't match, return it as-is
    }
}

# Convert QueryPeriod and QueryFrequency to ISO 8601
$queryPeriod = ""
if ($row.QueryPeriod){
    $queryPeriod = Convert-ToISO8601Duration -timeValue $row.QueryPeriod
    $queryPeriod = "query_frequency            = `"$($row.QueryPeriod)`""
}

$queryFrequency = ""
if ($row.QueryFrequency){
    $queryFrequency = Convert-ToISO8601Duration -timeValue $row.QueryFrequency
    $queryFrequency = "query_period               = `"$($row.QueryFrequency)`""
}

# Prepare Trigger Threshold
$TriggerThreshold = ""
if($row.TriggerThreshold){
    $TriggerThreshold = "trigger_threshold          = $($row.TriggerThreshold)"
}

# Prepare TriggerOperator
$triggerOperator = $row.TriggerOperator
if($triggerOperator){
    if ($triggerOperator -eq "gt") {
        $triggerOperator = "GreaterThan"
    }
    elseif ($triggerOperator -eq "lt") {
        $triggerOperator = "LessThan"
    }
    elseif ($triggerOperator -eq "eq") {
        $triggerOperator = "Equal"
    }
    elseif ($triggerOperator -eq "ne") {
        $triggerOperator = "NotEqual"
    }
    $triggerOperator = "trigger_operator = `"$($triggerOperator )`""
}

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

# Prepare alert details override section if available
$alertDetailsOverrideSection = ""
if ($row.AlertDetailsOverride) {
    $alertDetailsOverride = ConvertFrom-Json -InputObject $row.AlertDetailsOverride

    # Add description format if available
    if ($alertDetailsOverride.alertDescriptionFormat) {
        $alertDescriptionFormat = $alertDetailsOverride.alertDescriptionFormat
        $alertDescriptionFormat = $alertDescriptionFormat.Trim('"')  # Strip first and last double quotes

        # Now perform the replacements
        $alertDescriptionFormat = $alertDescriptionFormat -replace "`n|`r|'", ""
        $alertDescriptionFormat = $alertDescriptionFormat -replace "\\", "\\"
        $alertDescriptionFormat = $alertDescriptionFormat -replace "`"", "\`"" 
        $alertDetailsOverrideSection += "description_format = `"$($alertDescriptionFormat)`"`n"
    }


    # Add display name format if available
    if ($alertDetailsOverride.alertDisplayNameFormat) {
        $displayNameFormat = $alertDetailsOverride.alertDisplayNameFormat
        $displayNameFormat = $displayNameFormat.Trim('"')  # Strip first and last double quotes

        # Now perform the replacements
        $displayNameFormat = $displayNameFormat -replace "`n|`r|'", ""
        $displayNameFormat = $displayNameFormat -replace "\\", "\\"
        $displayNameFormat = $displayNameFormat -replace "`"", "\`"" 

        $alertDetailsOverrideSection += "display_name_format = `"$displayNameFormat`"`n"
    }

    # Add severity column name if available
    if ($alertDetailsOverride.alertSeverityColumnName) {
        $alertDetailsOverrideSection += "severity_column_name = `"$($alertDetailsOverride.alertSeverityColumnName)`"`n"
    }

    # Add tactics column name if available
    if ($alertDetailsOverride.alertTacticsColumnName) {
        $alertDetailsOverrideSection += "tactics_column_name = `"$($alertDetailsOverride.alertTacticsColumnName)`"`n"
    }

    # Handle dynamic properties if available
    if ($alertDetailsOverride.alertDynamicProperties) {
        foreach ($dynamicProperty in $alertDetailsOverride.alertDynamicProperties) {
            $alertDetailsOverrideSection += "dynamic_property {`n"
            $alertDetailsOverrideSection += "  alert_property = `"$($dynamicProperty.alertProperty)`"`n"
            $alertDetailsOverrideSection += "  value = `"$($dynamicProperty.value)`"`n"
            $alertDetailsOverrideSection += "}`n"
        }
    }

    if ($alertDetailsOverrideSection) {
        $alertDetailsOverrideSection = "  alert_details_override {`n" + $alertDetailsOverrideSection + "  }`n"
    }
}

# Prepare query to escape strings:
# https://developer.hashicorp.com/terraform/language/expressions/strings#escape-sequences-1
$query = $row.Query
$query = $query -replace "%", "%%" 
$query = $query -replace "\$", "`$`$`$`$" # Needs four to create two and escaping differs when used like this

# Main Template starts here:
@"
resource "azurerm_sentinel_alert_rule_scheduled" "ar_$guid" {
  // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_scheduled
  name                       = "$guid"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "$($row.Name)"
  severity                   = "$($row.Severity)"

  $tacticsOut  
  $techniquesOut
  $alertDetailsOverrideSection
  alert_rule_template_guid   = "$($row.Id)"
  alert_rule_template_version = "$($row.Version)"

  $triggerThreshold
  $triggerOperator

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
  $queryFrequency
  $queryPeriod
  query                      = <<EOQUERY
$query
EOQUERY
}
"@