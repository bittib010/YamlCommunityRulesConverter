[CmdletBinding()]
param (
    [string]$csvPath = (Join-Path -Path $PWD -ChildPath "temp/AzureSentinelRules.csv"),
    [string]$outputType,
    [string]$templateFolderPath = (Join-Path -Path $PWD -ChildPath "Templates"),
    [switch]$useIdAsFileName,
    [switch]$convertAll,
    [switch]$convertEnabled = $True
)

function Sanitize-FileName {
    param (
        [string]$fileName,
        [int]$maxLength = 200
    )
    # Hardcoded set of invalid characters for both Windows and Linux/Unix
    # Note: We're not using [IO.Path]::GetInvalidFileNameChars() because its output differs between Windows and Linux
    $invalidChars = '/><:"\|?*' -join ''

    # Replace invalid characters with underscores
    $sanitizedName = $fileName
    foreach ($char in $invalidChars.ToCharArray()) {
        $sanitizedName = $sanitizedName.Replace($char, '_')
    }

    # Truncate if longer than maxLength
    if ($sanitizedName.Length -gt $maxLength) {
        $sanitizedName = $sanitizedName.Substring(0, $maxLength)
    }

    return $sanitizedName
}

function Load-TemplateFiles {
    param (
        [string]$templateFolderPath,
        [string]$outputType
    )

    $templateFiles = Get-ChildItem -Path $templateFolderPath -Filter "*.ps1"
    $templates = @{}

    foreach ($file in $templateFiles) {
        $templateName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if ($templateName.Split("_")[0] -eq $outputType) {
            Write-Host "Loading template: $templateName from file: $($file.FullName)" -ForegroundColor Cyan
            $templates[$templateName] = $file.FullName
        }
    }
    
    return $templates
}

function Generate-Templates {
    param (
        [string]$csvPath,
        [string]$outputType,
        [string]$templateFolderPath
    )

    $templates = Load-TemplateFiles -templateFolderPath $templateFolderPath -outputType $outputType
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
            Write-Error "Invalid combination of outputType and ruleType: $outputType, $ruleType."
            continue
        }

        $output = & $templatePath

        # Use Id as the primary file name, fallback to sanitized FriendlyName
        $outputFileName = if ($row.Id) { 
            Sanitize-FileName -fileName $row.Id 
        }
        else { 
            Sanitize-FileName -fileName $row.FriendlyName 
        }

        $outputFilePath = switch ($outputType) {
            "bicep" { Join-Path ".\temp\BicepRules" $folder "$outputFileName.bicep" }
            "tfazurerm" { Join-Path ".\temp\TerraformAzRMRules" $folder "$outputFileName.tf" }
            "tfazapi" { Join-Path ".\temp\TerraformAzApiRules" $folder "$outputFileName.tf" }
            "arm" { Join-Path ".\temp\ARMRules" $folder "$outputFileName.json" }
            default {
                Write-Error "$outputType does not exist or has not been set by using the argument -OutputType 'tfazurerm', 'tfazapi'..."
                continue
            }
        }

        try {
            $outputDirectory = Split-Path -Path $outputFilePath -Parent
            if (-not (Test-Path $outputDirectory)) {
                New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
            }

            Set-Content -Path $outputFilePath -Value $output -ErrorAction Stop
            Write-Host "Generated file: $outputFilePath" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to write file: $outputFilePath. Error: $_"
        }
    }
}

if (Test-Path $csvPath) {
    Generate-Templates -csvPath $csvPath -outputType $outputType -templateFolderPath $templateFolderPath

    if ($outputType -in @("tfazurerm", "tfazapi")) {
        Write-Output "Formatting all rules with 'terraform fmt -recursive -list=false ./'"
        terraform fmt -recursive -list=false ./
    }
}
else {
    Write-Host "$csvPath does not exist. Run ListAllCommunityRules.ps1 before running this script."
}


# TODO: Remove newlines from sections that are not printed to file because not existing.
# TODO: Azure repo fixes to do:
#           - Fix missing severity on scheduled rules
# Look into techniques/tactics that they align with terraform correcly (no subtech and so on)
# Add fields to CSV to tell when the rule was first added, this will yield dates to track new rules with as well.
# TODO: Create an activator function/ps1 file that serves as a way to activate (set to true) rules that apply to a certain maximum of connectors/tables...
