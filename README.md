
# YamlCommunityRulesConverter
This script downloads the entier Azure Sentinel repo, looks for all Scheduled rules, NRT rules and hunting rules. Goes through them and translates all rules into a row within a CSV file. This CSV file is then used to go through to easily find all values needed to rebuild the rule in a given format via a template file.
## Limitations
- Currently only azurerm templates with fully conversion added, but not tested in practical deployment.
## Requirements

Preferably install the VSCode extension to view CSV in a table: janisdd.vscode-edit-csv
# Running
```powershell
# Generate the list to convert rules from
./ListAllCommunityRules.ps1
# Default filenames set to ID of the rule as it is supposedly static
.\ConvertToTemplate.ps1 -outputType "tfazurerm"
# Convert ALL possible rules instead of only the enabled ones
.\ConvertToTemplate.ps1 -outputType "tfazurerm" -convertAll
# Enable in the csv rules with given criterias for inputConnectors inputDataTypes, ruleTypeFilter, inputTactics, inputTechniques and run the converter on the csv:
.\EnableRulesByCondition.ps1 -csvPath .\AzureSentinelRules.csv -inputConnectors "AzureActivity", "BehaviorAnalytics" -ruleTypeFilter "Scheduled Rules" -inputTactics "ResourceDevelopment" 
```

# Contributing
Contributions are very much appreciated. Below is an explanation to do so, and I've tried making it a bit beginner friendly as well.
Code suggestions, improvements and more are much appreciated as well.
## Adding a new template
All rules are divided into "analytic", "hunt" and "nrt". Meaning that if you want to add a new template for a language be sure to use this naming convention:
- \<lang\>_analytic.ps1
- \<lang\>_hunt.ps1
- \<lang\>_nrt.ps1
Note: for multiple similar templates, add an iterating number behind.
When files has been created add a new "elseif" clause to this part of the file:
```powershell
if ($outputType -eq "bicep") {
    $outputFilePath = ".\temp\BicepRules\$folder\$outputFileName.bicep"
}
elseif ($outputType -eq "tfazurerm") {
    $outputFilePath = ".\temp\TerraformAzRMRules\$folder\$outputFileName.tf"
}
elseif ($outputType -eq "tfazapi") {
    $outputFilePath = ".\temp\TerraformAzApiRules\$folder\$outputFileName.tf"
}
elseif ($outputType -eq "arm") {
    $outputFilePath = ".\temp\armRules\$folder\$outputFileName.json"
} # Change or add the below to your need
elseif ($outputType -eq "<language>") {
    $outputFilePath += ".\temp\<language>Rules\$folder\$outputFileName.<extension>"
}
```
The language will be the argument to be used when calling the script to convert to this language. The extension will be added to the output file of each rule.
Below is a simplified example of hunting rule in Terraform
```powershell
# Prepare any needed variables based on each $row.Column
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
