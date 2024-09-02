[CmdletBinding()]
# Check for command-line arguments and set defaults if necessary
param (
    [string]$csvPath = ".\temp\AzureSentinelRules.csv",
    [string]$outputType,
    [string]$templateFolderPath = ".\Templates",
    [switch]$useIdAsFileName
)

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
        [string]$csvPath = ".\temp\AzureSentinelRules.csv",
        [string]$outputType,
        [string]$templateFolderPath = ".\Templates"
    )

    # Load templates from the specified folder
    $templates = Load-TemplateFiles -templateFolderPath $templateFolderPath

    # Load CSV file
    $csvData = Import-Csv -Path $csvPath

    # Loop through each row in the CSV and generate output
    foreach ($row in $csvData) {
        if ($row.Name -contains "[Deprecated]") {
            Write-Host("Skipping deprecated file: ", $row.Name)
            continue
        }
    
        # Generate a new GUID for each row
        $guid = [guid]::NewGuid().ToString()
    
        # Determine the rule type based on the Type column
        $folder, $ruleType = switch ($row.Type) {
            "Scheduled Rules" { "Scheduled", "analytic" }
            "Hunting Rules" { "Hunting", "hunt" }
            "NRT Rules" { "NRT", "nrt" }
            default { "Unknown", "unknown" }
        }
    
        if ($ruleType -eq "analytic") {
            if ($null -eq $row.Severity) {
                Write-Error("The rule with ID $($row.Id) is a Scheduled rule($ruleType), but is missing Severity ($($row.Severity))")
                continue
            }
        }
    
        # Check if a valid template exists for the combination of outputType and ruleType
        $templateKey = "${outputType}_${ruleType}"
        $templatePath = $templates[$templateKey]
    
        if (-not $templatePath) {
            Write-Error "Invalid combination of outputType and ruleType: $outputType, $ruleType ($($row.Type))"
            continue  # Skip to the next row if the combination is invalid
        }
        # Add variables that could be reached inside each template (all $row.<column> are available)
        # Prepare unique guid for each rule
        $guid = [guid]::NewGuid()

        # Execute the template script
        $output = & $templatePath
    
        # Determine the output file name based on the switch
        if ($useIdAsFileName) {
            $outputFileName = "$($row.Id)"
        }
        else {
            $outputFileName = "$($row.Name)".Replace(' ', '_').Replace(':', '').Replace('/', '').Replace('\', '')
        }
    
        # Determine the output file path and extension
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
            $outputFilePath = ".\temp\ARMRules\$folder\$outputFileName.json"
        }
        else {
            Write-Error($outputType, " does not exist")
            # TODO: Create a dynamical list of existing values and print it, or catch this error even earlier...
            # TODO: The list could be generated by reading all ps1 files inside ./Template, split by _ and use the [0] to generate a list...
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

Generate-Templates -csvPath $csvPath -outputType $outputType -templateFolderPath $templateFolderPath

if ($outputType -eq "tfazurerm" || $outputType -eq "azapi") {
    Write-Output ("Formatting all rules with 'terraform fmt -recursive -list=false ./'")
    terraform fmt -recursive -list=false ./ 
}
# TODO: output files to arg dest. Default to temp...
# TODO: Remove newlines from sections that are not printed to file because not existing.
# TODO: Azure repo fixes to do:
#           - Fix formatting on yaml files with MDE, MDO and more starting filenames
#           - Fix missing severity on scheduled rules
#           - Fix naming conventions using square brackets
# Look into techniques/tactics that they align with terraform correcly (no subtech and so on)
# Add fields to CSV to tell when the rule was first added, this will yield dates to track new rules with as well.
# TODO: add --all to convert all files or default to only selected, meaning all that has the enabled column set to true.
# TODO: Create an activator function/ps1 file that serves as a way to activate (set to true) rules that apply to a certain maximum of connectors/tables...
# TODO: Make a swith for terraform to create outputfilenames as alertRuleTemplateGuid instead (this makes it easier for quick lookup where filenames has a different name due to symbol restrictions in naming of files)??
