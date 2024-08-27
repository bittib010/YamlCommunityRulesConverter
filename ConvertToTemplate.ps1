# Function to load templates from files
function Load-TemplateFiles {
    param (
        [string]$templateFolderPath
    )

    $templateFiles = Get-ChildItem -Path $templateFolderPath -Filter "*.txt"
    $templates = @{}

    foreach ($file in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        Write-Host "Loading template: $templateName from file: $($file.FullName)" -ForegroundColor Green
        $templates[$templateName] = Get-Content -Path $file.FullName -Raw
    }

    return $templates
}


# Function to generate the output based on arguments
function Generate-Templates {
    param (
        [string]$csvPath,
        [string]$outputType,
        [string]$templateFolderPath
    )

    # Load templates from the specified folder
    $templates = Load-TemplateFiles -templateFolderPath $templateFolderPath

    # Load CSV file
    $csvData = Import-Csv -Path $csvPath

    # Loop through each row in the CSV and generate output
    foreach ($row in $csvData) {

        # Generate a new GUID for each row
        $guid = [guid]::NewGuid().ToString()

        # Determine the rule type based on the Type column
        $ruleType = if ($row.Type -eq "Scheduled Rules") {
            "analytic"
        } elseif ($row.Type -eq "Hunting Rules") {
            "hunt"
        } elseif ($row.Type -eq "NRT Rules") {
            "nrt"
        } else {
            "unknown" 
        }

        # Check if a valid template exists for the combination of outputType and ruleType
        $templateKey = "${outputType}_${ruleType}"
        $template = $templates[$templateKey]

        if (-not $template) {
            Write-Error "Invalid combination of outputType and ruleType: $outputType, $ruleType ($($row.Type))"
            continue  # Skip to the next row if the combination is invalid
        }

        # Replace placeholders with actual values from the row
        $output = $template
        $output = $output -replace "{{GUID}}", $guid
        $output = $output -replace "{{Name}}", $row.Name
        $output = $output -replace "{{Description}}", $row.Description
        $output = $output -replace "{{Query}}", $row.Query
        $output = $output -replace "{{Severity}}", $row.Severity

        # Output the final template for this row
        Write-Output $output
        Write-Output "`n"  # Add a newline for separation
    }
}

# Example of running the function with different arguments
$csvPath = "C:\temp\AzureSentinelRules.csv"
$outputType = "terraform"  # or "yaml"
$templateFolderPath = ".\Templates"

Generate-Templates -csvPath $csvPath -outputType $outputType -templateFolderPath $templateFolderPath


# TODO: add workspacename as a parameter to change in or consider using it as a var