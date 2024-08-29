$formattedDescription = ""
if ($row.Description) {
    # Prepare Description to not be printed on multiple lines.
    $huntDescription = $row.Description
    $huntDescription = $huntDescription -replace "`n|`r|'", ""
    $huntDescription = $huntDescription -replace "\\", "\\" # First is regular expression, second i ACTUAL output...
    $huntDescription = $huntDescription -replace '""', '"' # Reduce double to single
    $huntDescription = $huntDescription -replace '"', '\"' # Handle single 


    if ($huntDescription.Length -gt 150) {
        # If length is longer than 150, truncate
        $huntDescription = $huntDescription.Substring(0, 150)  # Take the first 150 characters
    }

    # Ensure that the final string ends with a properly escaped double quote
    if($huntDescription[-1] -ne '"'){
      $huntDescription = $huntDescription.TrimEnd('"')
    }
    $formattedDescription = "`"description`" : `"$huntDescription`","
}

# Prepare Tactics if available
$tacticsTags = ""
if ($row.Tactics) {
    $tacticsTags = "    `"tactics`" = `"$($row.Tactics)`","
}
# Prepare RelevantTechniques if available
$techniquesTags = ""
if ($row.RelevantTechniques) {
    $techniquesTags = "    `"techniques`" = `"$($row.RelevantTechniques)`","
}
# Prepare ID if available
$idTags = ""
if ($row.Id) {
    $idTags = "    `"id`" = `"$($row.Id)`","
}
# Prepare Version if available
$versionTags = ""
if ($row.Version) {
    $versionTags = "    `"alert_rule_template_version`" = `"$($row.Version)`""
}

# Prepare query
$query = $row.Query
$query = $query -replace "%", "%%" 
$query = $query -replace "\$", "`$`$`$`$" # Needs four to create two and escaping differs when used like this

# Main Template starts here:
@"
resource "azurerm_log_analytics_saved_search" "hunt_$guid" {
  // https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_saved_search
  name                       = "$guid"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  category     = "Hunting Queries"
  display_name = "$($row.Name)"

    tags = {
    $tacticsTags
    $techniquesTags
    // Currently, there is a limit of 150 characters for tags properties, this affects a lot of the hunting queries' descriptions...
    $formattedDescription
    $idTags
    $versionTags
  }
  query        = <<-EOQUERY
  $query

  EOQUERY
}
"@

# TODO: alternating between equals and colon inside tags, correct or not?