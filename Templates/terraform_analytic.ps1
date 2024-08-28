$guid = New-Guid
$name = "{{Name}}"
$severity = "{{Severity}}"
$tacticsArray = $row.Tactics -split ', '
$tactics = ($tacticsArray | ForEach-Object { "'$_'" }) -join ', '
$techniquesArray = $row.RelevantTechniques -split ', '
$techniques = ($techniquesArray | ForEach-Object { "'$($_ -split '\.')[0]'" }) -join ', '
$entityMappingsArray = $row.EntityMappings -split '; '
$entityMappings = if ($entityMappingsArray) {
    ($entityMappingsArray | ForEach-Object {
        $parts = $_ -split ': '
        "entityType: $($parts[0]), fieldMappings: $($parts[1])"
    }) -join '; '
} else {
    "{}"
}

$id = $row.Id
$description = $row.Description
$Query = $row.Query
$queryPeriod = $row.QueryPeriod
$queryFrequency = $row.QueryFrequency
$TriggerThreshold = $row.TriggerThreshold
$TriggerOperator = $row.TriggerOperator
$version = $row.Version

@"
resource "azurerm_sentinel_alert_rule_scheduled" "ar_$guid" {
  // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_scheduled
  name                       = "$guid"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  display_name               = "$name"
  severity                   = "$severity"

  tactics                    = [$tactics] // Comma separated and quoted
  techniques                 = [$techniques] // Comma separated and quoted, no subtechniques
  alert_details_override     = {}
  alert_rule_template_guid   = "$id"
  alert_rule_template_version = "$version"

  trigger_threshold          = {{TriggerThreshold}}

  custom_details             = {}
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
{{Query}}
QUERY
}
"@
