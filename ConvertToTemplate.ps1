# Function to load templates from files
function Load-TemplateFiles {
    param (
        [string]$templateFolderPath
    )

    $templateFiles = Get-ChildItem -Path $templateFolderPath -Filter "*.ps1"
    $templates = @{}

    foreach ($file in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        Write-Host "Loading template: $templateName from file: $($file.FullName)" -ForegroundColor Green
        $templates[$templateName] = $file.FullName
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
        if($row.Name -contains "[Deprecated]"){
            Write-Host("Skipping deprecated file: ", $row.Name)
            continue
        }
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
        $templatePath = $templates[$templateKey]

        if (-not $templatePath) {
            Write-Error "Invalid combination of outputType and ruleType: $outputType, $ruleType ($($row.Type))"
            continue  # Skip to the next row if the combination is invalid
        }

        # Prepare unique guid for each rule
        $guid = [guid]::NewGuid()

        # Define variables that will be used in the template
        $Id = $row.Id
        $Name = $row.Name
        $Description = $row.Description
        $Query = $row.Query
        $Severity = $row.Severity
        $QueryPeriod = $row.QueryPeriod
        $QueryFrequency = $row.QueryFrequency
        $Tactics = $row.Tactics
        $TriggerThreshold = $row.TriggerThreshold
        $TriggerOperator = $row.TriggerOperator
        $Version = $row.Version
        $RelevantTechniques = $row.RelevantTechniques
        $EntityMappings = $row.EntityMappings

        # Execute the template script
        $output = & $templatePath

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

# Format according to official style and do not display format changes
Write-Output ("Formatting all rules........")
terraform fmt -recursive -list=false ./ 

# TODO: add workspacename as a parameter to change in or consider using it as a var
# TODO: Strip newlines inside description to be escaped newlines instead and then Sentinel can handle it instead
# TODO: outtput files to arg dest. Default to temp...