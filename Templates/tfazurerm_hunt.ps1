# Function to handle hunting entity queries from CSV data
function Handle-HuntingEntityQueries { 
  param(
      [Parameter(Mandatory = $true)]
      $query,
      [Parameter(Mandatory = $true)]
      $entityMappingsRaw
  )

  $dupTracker = @{}
  $outputLines = @()
      
  $entityMappingEntries = $entityMappingsRaw -split 'entityType: '
  
  foreach ($entry in $entityMappingEntries) {
      if ($entry.Trim() -eq "") { continue } 
      
      $entityType = ($entry -split ',')[0].Trim()
      $fieldMappingsRaw = ($entry -split 'fieldMappings: ')[1].Trim()
      
      $fieldMappings = @()
      $fields = $fieldMappingsRaw -split ', '
      foreach ($field in $fields) {
          $fieldParts = $field -split ':'
          if ($fieldParts.Length -eq 2) {
              $identifier = $fieldParts[0].Trim()
              $columnName = $fieldParts[1].Trim()
              $fieldMappings += @{ identifier = $identifier; columnName = $columnName }
          } else {
              Write-Warning "Field mapping '$field' is not in the expected format 'identifier:columnName'. Skipping..."
          }
      }
      
      foreach ($fieldMapping in $fieldMappings) {
          $identifier = $fieldMapping.identifier
          $columnName = $fieldMapping.columnName

          $key = $entityType + '_' + $identifier
          if ($dupTracker.ContainsKey($key)) {
              $dupTracker[$key]++
          } else {
              $dupTracker[$key] = 0
          }

          $line = "| extend {0}_{1}_{2} = {3}" -f $entityType, $dupTracker[$key], $identifier, $columnName
          $line = $line.TrimEnd(';')
          $outputLines += $line
      }
  }

  if ($outputLines.Count -gt 0) {
      $outputString = $outputLines -join "`n"
      return $outputString
  }
  return ""
}

$formattedDescription = ""
if ($row.Description) {
  # Prepare Description to not be printed on multiple lines.
  $huntDescription = $row.Description
  $huntDescription = $huntDescription -replace "`n|`r|'", ""
  $huntDescription = $huntDescription -replace "\\", "\\" 
  $huntDescription = $huntDescription -replace '""', '"'  
  $huntDescription = $huntDescription -replace '"', '\"'  

  if ($huntDescription.Length -gt 150) {
      $huntDescription = $huntDescription.Substring(0, 150)  
  }

  if ($huntDescription[-1] -ne '"') {
      $huntDescription = $huntDescription.TrimEnd('"')
  }
  $formattedDescription = "`"description`" : `"$huntDescription`","
}

$tacticsTags = ""
if ($row.Tactics) {
  $tacticsTags = "    `"tactics`" = `"$($row.Tactics)`","
}

$techniquesTags = ""
if ($row.RelevantTechniques) {
  $techniquesTags = "    `"techniques`" = `"$($row.RelevantTechniques)`","
}

$idTags = ""
if ($row.Id) {
  $idTags = "    `"id`" = `"$($row.Id)`","
}

$versionTags = ""
if ($row.Version) {
  $versionTags = "    `"alert_rule_template_version`" = `"$($row.Version)`""
}

$query = $row.Query
$query = $query -replace "%", "%%" 
$query = $query -replace "\$", "`$`$`$`$" # Escaping for $ signs

# Check for existing "_0_" in query, if not present, handle entity mappings
if ($query -notmatch "_0_") {
  $entityMappingOutput = Handle-HuntingEntityQueries -query $query -entityMappingsRaw $row.EntityMappings

  if ($entityMappingOutput -ne "") {
      $query += "`n$entityMappingOutput"
  }
}

# Main Template starts here:
@"
resource "azurerm_log_analytics_saved_search" "hunt_$guid" {
name                       = "$guid"
log_analytics_workspace_id = var.log_analytics_workspace_id

category     = "Hunting Queries"
display_name = "$($row.Name)"

tags = {
  $tacticsTags
  $techniquesTags
  $formattedDescription
  $idTags
  $versionTags
}
query        = <<-EOQUERY
$query

EOQUERY
}
"@
