[CmdletBinding()]
param (
    [string]$csvPath = ".\temp\AzureSentinelRules.csv",
    [string]$outputType,
    [string]$templateFolderPath = ".\Templates",
    [switch]$useIdAsFileName,
    [switch]$convertAll,
    [switch]$convertEnabled = $True
)

function Load-TemplateFiles {
    param (
        [string]$templateFolderPath
    )

    $templateFiles = Get-ChildItem -Path $templateFolderPath -Filter "*.ps1"
    $templates = @{}

    foreach ($file in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        Write-Host "Loading template: $templateName from file: $($file.FullName)" -ForegroundColor Cyan
        $templates[$templateName] = $file.FullName
    }

    return $templates
}

function Generate-Templates {
    param (
        [string]$csvPath,
        [string]$outputType,
        [string]$templateFolderPath
    )

    $templates = Load-TemplateFiles -templateFolderPath $templateFolderPath
    $csvData = Import-Csv -Path $csvPath

    foreach ($row in $csvData) {
        if (-not $convertAll -and $convertEnabled -and $row.CurrentlyEnabled -ne "True") {
            #Write-Host "Skipping rule $($row.Name) as it is not enabled and convertAll is not set." -ForegroundColor Yellow
            continue
        }

        $guid = [guid]::NewGuid().ToString()
        $folder, $ruleType = switch ($row.Type) {
            "Scheduled Rules" { "Scheduled", "analytic" }
            "Hunting Rules" { "Hunting", "hunt" }
            "NRT Rules" { "NRT", "nrt" }
            default { "Unknown", "unknown" }
        }

        if ($ruleType -eq "analytic" -and -not $row.Severity) {
            Write-Error "The rule with ID $($row.Id) is a Scheduled rule($ruleType), but is missing Severity."
            continue
        }

        $templateKey = "${outputType}_${ruleType}"
        $templatePath = $templates[$templateKey]

        if (-not $templatePath) {
            Write-Error "Invalid combination of outputType and ruleType: $outputType, $ruleType ($($row.Type))"
            continue
        }

        $output = & $templatePath
    
        # Determine the output file name based on the switch
        $outputFileName = if ($useIdAsFileName) { "$($row.Id)" } else { "$($row.Name)".Replace(' ', '_').Replace(':', '').Replace('/', '').Replace('\', '') }
    
        # Determine the output file path and extension
        $outputFilePath = switch ($outputType) {
            "bicep" { ".\temp\BicepRules\$folder\$outputFileName.bicep" }
            "tfazurerm" { ".\temp\TerraformAzRMRules\$folder\$outputFileName.tf" }
            "tfazapi" { ".\temp\TerraformAzApiRules\$folder\$outputFileName.tf" }
            "arm" { ".\temp\ARMRules\$folder\$outputFileName.json" }
            default {
                Write-Error "$outputType does not exist"
                continue
            }
        }
    
        # Ensure the directory exists
        $outputDirectory = Split-Path -Path $outputFilePath
        if (-not (Test-Path $outputDirectory)) {
            New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
        }

        Set-Content -Path $outputFilePath -Value $output
        Write-Host "Generated file: $outputFilePath" -ForegroundColor Green
    }
}

if (Test-Path $csvPath) {
    Generate-Templates -csvPath $csvPath -outputType $outputType -templateFolderPath $templateFolderPath

    if ($outputType -in @("tfazurerm", "azapi")) {
        Write-Output "Formatting all rules with 'terraform fmt -recursive -list=false ./'"
        terraform fmt -recursive -list=false ./
    }
}
else {
    Write-Host "$csvPath does not exist. Run ListAllCommunityRules.ps1 before running this script."
}




# TODO: output files to arg dest. Default to temp...
# TODO: Remove newlines from sections that are not printed to file because not existing.
# TODO: Azure repo fixes to do:
#           - Fix missing severity on scheduled rules
# Look into techniques/tactics that they align with terraform correcly (no subtech and so on)
# Add fields to CSV to tell when the rule was first added, this will yield dates to track new rules with as well.
# TODO: add --all to convert all files or default to only selected, meaning all that has the enabled column set to true.
# TODO: Create an activator function/ps1 file that serves as a way to activate (set to true) rules that apply to a certain maximum of connectors/tables...
# TODO: Make a swith for terraform to create outputfilenames as alertRuleTemplateGuid instead (this makes it easier for quick lookup where filenames has a different name due to symbol restrictions in naming of files)??
