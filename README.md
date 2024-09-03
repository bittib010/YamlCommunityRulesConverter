# YamlCommunityRulesConverter
This script downloads the entier Azure Sentinel repo, looks for all Scheduled rules, NRT rules and hunting rules. Goes through them and translates all rules into a row within a CSV file. This CSV file is then used to go through to easily find all values needed to rebuild the rule in a given format via a template file.

## Limitations
- Only tested on Windows
- Works best with Powershell7
- Currently only azurerm templates with fully conversion added, but tested in practice.
- Error messages still warning on too long filepaths even after enabling Windows Long Path. It may be beneficial to run the script as close to C: as possible.

## Requirements

Enable Windows Long Path by running (https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell):
```powershell
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

Preferably install the extension to view CSV in a table: janisdd.vscode-edit-csv

Run without Prettier

Run to get and convert all rules to Terraform AzureRM.
```powershell
./ListAllCommunityRules.ps1
# With filenames set to ID of the rule
.\ConvertToTemplate.ps1 -outputType "tfazurerm" -useIdAsFileName
# With filenames set to the rulename itself:
.\ConvertToTemplate.ps1 -outputType "tfazurerm"
```


# Contributing
Contributions are very much appreciated. Below is an explanation to do so, and I've tried making it a bit beginner friendly as well.

Code suggestions, improvements and more are much appreciated as well.

## Adding a new template
All rules are divided into "analytic", "hunt" and "nrt". Meaning that if you want to add a new template for a language be sure to use this naming convention:
- \<lang\>_analytic.ps1
- \<lang\>_hunt.ps1
- \<lang\>_nrt.ps1

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
elseif ($outputType -eq "jsonApi") {
    $outputFilePath = ".\temp\jsonApiRules\$folder\$outputFileName.json"
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