# YamlCommunityRulesConverter
This script downloads the entier Azure Sentinel repo, looks for all Scheduled rules, NRT rules and hunting rules. Goes through them and translates all rules into a row within a CSV file. This CSV file is then used to go through to easily find all values needed to rebuild the rule in a given format via a template file.

## Requirements
Preferably install the extension to view CSV in a table: janisdd.vscode-edit-csv

Run without Prettier

Run to get and convert all rules to Terraform.
```powershell
./ListAllCommunityRules.ps1
ConvertToTemplate.ps1
```

Run to get and convert all rules to Bicep
```powershell
./ListAllCommunityRules.ps1
ConvertToTemplate.ps1
```
# Contributing
Contributions are very much appreciated. Below is an explanation to do so, and I've tried making it a bit beginner friendly as well.

Code suggestions, improvements and more are much appreciated as well.

## Adding a new template
All rules are divided into "analytic", "hunt" and "nrt". Meaning that if you want to add a new template for a language be sure to use this naming convention:
- \<lang\>_analytic.ps1
- \<lang\>_hunt.ps1
- \<lang\>_nrt.ps1
:
Below is a simplified example of hunting rule in Terraform
```powershell
# Prepare any needed structure here based
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
  name                       = "$guid"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  category     = "Hunting Queries"
  display_name = "$($row.Name)"

    tags = {
    "description"  = "$($row.Description)
    $idTags
    $versionTags
  }
  query        = <<-EOQUERY
  $query

  EOQUERY
}
"@
```

## Explanation
$guid is available from the ConvertToTemplate.ps1. If there is a need for new global variables (used accross multiple templates), please add them to that file, instead of creating a new within your template. This makes the code more readable.

Within each template file, you have access to the current rule's row. Meaning, all columns from the CSV are available, but all rules may not have data in each column, so do a check for this when preparing the data. Access them by $row.\<columnName\>