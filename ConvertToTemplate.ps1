# Define the template strings for each combination of outputType and ruleType
$templates = @{
    "yaml_hunt" = @"
- type: hunt
  name: {{Name}}
  description: {{Description}}
  query: |
    {{Query}}
"@

    "yaml_analytic" = @"
- type: analytic
  name: {{Name}}
  description: {{Description}}
  query: |
    {{Query}}
"@

    "yaml_nrt" = @"
- type: nrt
  name: {{Name}}
  description: {{Description}}
  query: |
    {{Query}}
"@

    "terraform_hunt" = @"
resource "hunt_rule" "{{Name}}" {
  description = "{{Description}}"
  query       = <<QUERY
    {{Query}}
QUERY
}
"@

    "terraform_analytic" = @"
resource "analytic_rule" "{{Name}}" {
  description = "{{Description}}"
  query       = <<QUERY
    {{Query}}
QUERY
}

resource "azurerm_sentinel_alert_rule_scheduled" "ar_{{New-Guid}}" {
  name                       = "{{<use the same GUID here}}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.example.workspace_id
  display_name               = "example"
  severity                   = "High"
  query                      = <<QUERY
AzureActivity |
  where OperationName == "Create or Update Virtual Machine" or OperationName =="Create Deployment" |
  where ActivityStatus == "Succeeded" |
  make-series dcount(ResourceId) default=0 on EventSubmissionTimestamp in range(ago(7d), now(), 1d) by Caller
QUERY
}
"@

    "terraform_nrt" = @"
resource "nrt_rule" "{{Name}}" {
  description = "{{Description}}"
  query       = <<QUERY
    {{Query}}
QUERY
}
"@
}

# Function to generate the output based on arguments
function Generate-Templates {
    param (
        [string]$csvPath,
        [string]$outputType
        )

    # Load CSV file
    $csvData = Import-Csv -Path $csvPath

    $ruleType = if ($row.Type -eq "Scheduled Rules") {
        "analytic"
    } elseif ($row.Type -eq "Hunting Rules") {
        "hunt"
    } elseif ($row.Type -eq "NRT Rules") {
        "nrt"
    } else {
        "unknown" 
    }
    $templateKey = "${outputType}_${ruleType}"
    $template = $templates[$templateKey]

    if (-not $template) {
        Write-Error "Invalid combination of outputType and ruleType: $outputType, $ruleType"
        return
    }

    # Loop through each row in the CSV and generate output
    foreach ($row in $csvData) {
        $output = $template
        $output = $output -replace "{{Name}}", $row.Name
        $output = $output -replace "{{Description}}", $row.Description
        $output = $output -replace "{{Query}}", $row.Query

        # Output the final template for this row
        Write-Output $output
        Write-Output "`n"  # Add a newline for separation
    }
}

# Example of running the function with different arguments
$csvPath = "path\to\your\file.csv"
$outputType = "yaml"  # or "terraform"

Generate-Templates -csvPath $csvPath -outputType $outputType
