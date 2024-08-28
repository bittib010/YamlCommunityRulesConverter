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
        $folder, $ruleType = switch ($row.Type) {
            "Scheduled Rules" { "Scheduled", "analytic" }
            "Hunting Rules"   { "Hunting", "hunt" }
            "NRT Rules"       { "NRT", "nrt" }
            default           { "Unknown", "unknown" }
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
        $output = $output -replace "{{Id}}", $row.Id
        $output = $output -replace "{{Name}}", $row.Name
        $output = $output -replace "{{Description}}", $row.Description -replace "`r`n", "`n" -replace "`n", "`n"
        $output = $output -replace "{{Query}}", $row.Query
        $output = $output -replace "{{Severity}}", $row.Severity
        $output = $output -replace "{{QueryPeriod}}", $row.QueryPeriod
        $output = $output -replace "{{QueryFrequency}}", $row.QueryFrequency
        $output = $output -replace "{{Tactics}}", $row.Tactics
        $output = $output -replace "{{TriggerThreshold}}", $row.TriggerThreshold
        $output = $output -replace "{{TriggerOperator}}", $row.TriggerOperator
        $output = $output -replace "{{Version}}", $row.Version
        $output = $output -replace "{{RelevantTechniques}}", $row.RelevantTechniques
        $output = $output -replace "{{EntityMappings}}", $row.EntityMappings

        # Determine the output file path and extension
        $outputFileName = "$($row.Name)".Replace(' ', '_').Replace(':', '').Replace('/', '').Replace('\', '')
        $outputFilePath = ".\temp\Rules\$folder\$outputFileName"

        if ($outputType -eq "yaml") {
            $outputFilePath += ".yaml"
        } elseif ($outputType -eq "terraform") {
            $outputFilePath += ".tf"
        }

        # Ensure the directory exists
        $outputDirectory = Split-Path -Path $outputFilePath
        if (-not (Test-Path $outputDirectory)) {
            New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
        }

        # Write the final template to a file
        Set-Content -Path $outputFilePath -Value $output
        Write-Host "Generated file: $outputFilePath"
    }
}

# Example of running the function with different arguments
$csvPath = ".\temp\AzureSentinelRules.csv"
$outputType = "terraform"  # or "yaml"
$templateFolderPath = ".\Templates"

Generate-Templates -csvPath $csvPath -outputType $outputType -templateFolderPath $templateFolderPath

# TODO: add workspacename as a parameter to change in or consider using it as a var
# TODO: Strip newlines inside description to be escaped newlines instead and then Sentinel can handle it instead
# TODO: outtput files to arg dest. Default to temp...