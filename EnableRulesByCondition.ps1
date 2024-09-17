[CmdletBinding()]
param (
    [string]$csvPath = (Join-Path -Path $PWD -ChildPath "./AzureSentinelRules.csv"),
    [array]$inputConnectors = @(), 
    [array]$inputDataTypes = @(),  
    [string]$ruleTypeFilter,       
    [array]$inputTactics = @(),    
    [array]$inputTechniques = @()  
)

function Parse-DataConnectors {
    param (
        [string]$dataConnectorsString
    )

    $connectorDataTypeMap = @{}

    $connectors = $dataConnectorsString -split ';'

    foreach ($connector in $connectors) {
        $parts = $connector -split ':'

        if ($parts.Length -eq 2) {
            $connectorName = $parts[0].Trim()
            $dataTypes = $parts[1].Trim() -split ','

            if (-not $connectorDataTypeMap.ContainsKey($connectorName)) {
                $connectorDataTypeMap[$connectorName] = @()
            }

            foreach ($dataType in $dataTypes) {
                $connectorDataTypeMap[$connectorName] += $dataType.Trim()
            }

            $connectorDataTypeMap[$connectorName] = $connectorDataTypeMap[$connectorName] | Sort-Object -Unique
        }
    }

    return $connectorDataTypeMap
}

function Should-EnableRule {
    param (
        [hashtable]$ruleConnectors,
        [array]$inputConnectors,
        [array]$inputDataTypes,
        [array]$ruleTactics,
        [array]$ruleTechniques,
        [array]$inputTactics,
        [array]$inputTechniques
    )

    # 1. Check connectors and data types if provided
    if ($inputConnectors.Count -gt 0) {
        foreach ($connector in $ruleConnectors.Keys) {
            if (-not $inputConnectors -contains $connector) {
                return $false  # Exclude if the connector is not in inputConnectors
            }
        }
    }

    if ($inputDataTypes.Count -gt 0) {
        foreach ($connector in $ruleConnectors.Keys) {
            $ruleDataTypes = $ruleConnectors[$connector]
            foreach ($dataType in $ruleDataTypes) {
                if (-not $inputDataTypes -contains $dataType) {
                    return $false  # Exclude if the data type is not in inputDataTypes
                }
            }
        }
    }

    # 2. Check tactics if provided
    if ($inputTactics.Count -gt 0) {
        if ($ruleTactics.Count -eq 0 -or ($ruleTactics | Where-Object { $inputTactics -notcontains $_ }).Count -gt 0) {
            return $false  # Exclude if ruleTactics don't match inputTactics
        }
    }

    # 3. Check techniques if provided
    if ($inputTechniques.Count -gt 0) {
        if ($ruleTechniques.Count -eq 0 -or ($ruleTechniques | Where-Object { $inputTechniques -notcontains $_ }).Count -gt 0) {
            return $false  # Exclude if ruleTechniques don't match inputTechniques
        }
    }

    return $true
}

function Update-Csv {
    param (
        [string]$csvPath,
        [array]$inputConnectors,
        [array]$inputDataTypes,
        [string]$ruleTypeFilter,
        [array]$inputTactics,
        [array]$inputTechniques
    )

    $csvData = Import-Csv -Path $csvPath
    $counter = 0

    foreach ($row in $csvData) {
        # Skip rules that are already enabled
        if ($row.CurrentlyEnabled -eq "True") {
            continue
        }

        # Filter by rule type if provided (filter IN)
        if ($ruleTypeFilter -and $row.Type -ne $ruleTypeFilter) {
            continue
        }

        $requiredDataConnectors = $row.RequiredDataConnectors
        $ruleTactics = if ($row.Tactics -ne $null) { $row.Tactics -split ',' } else { @() }
        $ruleTechniques = if ($row.RelevantTechniques -ne $null) { $row.RelevantTechniques -split ',' } else { @() }

        $ruleConnectors = Parse-DataConnectors -dataConnectorsString $requiredDataConnectors

        $shouldEnable = Should-EnableRule -ruleConnectors $ruleConnectors `
                                          -inputConnectors $inputConnectors `
                                          -inputDataTypes $inputDataTypes `
                                          -ruleTactics $ruleTactics `
                                          -ruleTechniques $ruleTechniques `
                                          -inputTactics $inputTactics `
                                          -inputTechniques $inputTechniques

        if ($shouldEnable) {
            $row.CurrentlyEnabled = "True"
            Write-Host "Rule $($row.Id) enabled based on the input criteria." -ForegroundColor Green
            $counter += 1  
        }
    }

    # Ensure proper column order for exporting
    $orderedCsvData = $csvData | Select-Object "RequiredDataConnectors", "TriggerThreshold", "Metadata", "QueryFrequency", "Version", "Name", "Tactics", "EntityMappings", "Link", "Description", "FriendlyName", "Severity", "NameGuid", "RelevantTechniques", "CurrentlyEnabled", "QueryPeriod", "SuppressionEnabled", "AlertDetailsOverride", "Id", "Type", "CustomDetails", "Added", "TriggerOperator", "SuppressionDuration", "Query"

    # Export the updated CSV back without adding quotes unnecessarily
    $orderedCsvData | Export-Csv -Path $csvPath -NoTypeInformation -Force
    Write-Host "$counter rules were updated and enabled."
}

if (Test-Path $csvPath) {
    Update-Csv -csvPath $csvPath `
               -inputConnectors $inputConnectors `
               -inputDataTypes $inputDataTypes `
               -ruleTypeFilter $ruleTypeFilter `
               -inputTactics $inputTactics `
               -inputTechniques $inputTechniques
} else {
    Write-Host "$csvPath does not exist. Please provide a valid CSV file path."
}
