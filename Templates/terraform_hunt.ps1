# Prepare Description to not be printed on multiple lines.
$description = $row.Description
$description = $description -replace "`n|`r|'", ""
$description = $description -replace "\\", "\\"
$description = $description -replace "`"", "\`"" 
if ($description.Length -gt 150) { # If length is longer than 150
  $description = $description.Substring(0, 149)
}

# Prepare Tactics if available
$tacticsTags = ""
if ($row.Tactics) {
    $tacticsTags = "    `"tactics`"                     = `"$($row.Tactics)`","
}
# Prepare RelevantTechniques if available
$techniquesTags = ""
if ($row.RelevantTechniques) {
    $techniquesTags = "    `"techniques`"                     = `"$($row.RelevantTechniques)`","
}
# Prepare ID if available
$idTags = ""
if ($row.RelevantTechniques) {
    $idTags = "    `"techniques`"                     = `"$($row.Id)`","
}
# Prepare Version if available
$versionTags = ""
if ($row.RelevantTechniques) {
    $versionTags = "    `"techniques`"                     = `"$($row.Version)`""
}

if ($row.Description){
  "`"description`"                 : `"$description`","

}


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
    "description"                 : "$description",
    $idTags
    $versionTags
  }
  query        = <<-EOQUERY
  $($row.Query)

  EOQUERY
}
"@

# TODO: alternating between equals and colon inside tags, correct or not?