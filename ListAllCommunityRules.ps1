# Function to ensure powershell-yaml module is available
function Test-RequiredModules {
    $moduleNames = @("powershell-yaml")
    
    foreach ($moduleName in $moduleNames) {
        try {
            if (-not (Get-Module -ListAvailable -Name $moduleName)) {
                Write-Verbose "PowerShell-Yaml module not found. Attempting to install..."
                Install-Module -Name $moduleName -Force -Scope CurrentUser -ErrorAction Stop
                Write-Verbose "PowerShell-Yaml module installed successfully."
            }
            else {
                Write-Verbose "PowerShell-Yaml module is already installed."
            }

            Import-Module $moduleName -ErrorAction Stop
            Write-Verbose "PowerShell-Yaml module imported successfully."
        }
        catch {
            Write-Error "Failed to install or import the PowerShell-Yaml module: $_"
            throw
        }
    }
}

# Ensure requiuired modules are available
Test-RequiredModules

# Set the path to the cloned Azure-Sentinel directory
$TempFolder = Join-Path -Path $PWD -ChildPath "temp/Azure-Sentinel"
$OutputCsv = Join-Path -Path $PWD -ChildPath "temp/AzureSentinelRules.csv"

Function Get-YamlContent {
    param(
        [string]$filePath
    )

    try {
        $content = Get-Content -LiteralPath $filePath -Raw
        return $content | ConvertFrom-Yaml
    }
    catch {
        Write-Error "Failed to parse YAML file: $filePath. Error: $_"
        return $null
    }
}

Function Process-YamlFile {
    param(
        [string]$filePath,
        [hashtable]$existingRules
    )

    if ($filePath -like "*invalidFile.yaml") {
        return $null
    }

    $yamlContent = Get-YamlContent -filePath $filePath

    

    if ($null -eq $yamlContent -or $null -eq $yamlContent.id -or [string]::IsNullOrEmpty($yamlContent.name) -or [string]::IsNullOrEmpty($yamlContent.query)) {
        return $null
    }
    elseif ([String]$yamlContent.name -match "\[Deprecated\]") {
        return $null
    }

    $type = switch ($yamlContent.kind) {
        "scheduled" { "Scheduled Rules" }
        "nrt" { "NRT Rules" }
        default { "Hunting Rules" }
    }

    # Generate the correct GitHub link
    $relativePath = $filePath -replace [regex]::Escape("$TempFolder\"), ""
    $relativePath = $relativePath -replace '\\', '/'
    $link = "https://github.com/Azure/Azure-Sentinel/blob/master/$relativePath"

    $isNewRule = $false

    # Check if the rule already exists to preserve the "Added" date and "CurrentlyEnabled" state
    if ($existingRules.ContainsKey($yamlContent.id)) {
        $existingRule = $existingRules[$yamlContent.id]
        $addedDate = $existingRule.Added
        $currentlyEnabled = $existingRule.CurrentlyEnabled
    }
    else {
        $addedDate = Get-Date
        $currentlyEnabled = $false
        $isNewRule = $true  # Mark this rule as new
    }

    # Handle Entity Mappings
    $entityMappings = ""
    if ($yamlContent.entityMappings) {
        foreach ($mapping in $yamlContent.entityMappings) {
            $entityType = $mapping.entityType
            $entityMappings += "entityType: $entityType, fieldMappings: "

            $fieldMappings = @()
            foreach ($fieldMapping in $mapping.fieldMappings) {
                $fieldMappings += "$($fieldMapping.identifier): $($fieldMapping.columnName)"
            }

            $entityMappings += ($fieldMappings -join ', ') + "; "
        }
    }

    $tags = @{}
    if ($yamlContent.tags) {
        $i = 1
        foreach ($tag in $yamlContent.tags) {
            foreach ($tagKey in $tag.Keys) {
                $tags["Tag${i}_${tagKey}"] = $tag.$tagKey
            }
            $i++
        }
    }

    # Flatten incident configuration
    $incidentConfig = @{}
    if ($yamlContent.incidentConfiguration) {
        $incidentConfig["IncidentConfiguration_CreateIncident"] = $yamlContent.incidentConfiguration.createIncident
        if ($yamlContent.incidentConfiguration.groupingConfiguration) {
            $groupConfig = $yamlContent.incidentConfiguration.groupingConfiguration
            $incidentConfig["IncidentConfiguration_Grouping_Enabled"] = $groupConfig.enabled
            $incidentConfig["IncidentConfiguration_Grouping_ReopenClosedIncident"] = $groupConfig.reopenClosedIncident
            $incidentConfig["IncidentConfiguration_Grouping_LookbackDuration"] = $groupConfig.lookbackDuration
            $incidentConfig["IncidentConfiguration_Grouping_MatchingMethod"] = $groupConfig.matchingMethod
            $incidentConfig["IncidentConfiguration_Grouping_GroupByEntities"] = $groupConfig.groupByEntities -join ', '
            $incidentConfig["IncidentConfiguration_Grouping_GroupByAlertDetails"] = $groupConfig.groupByAlertDetails -join ', '
            $incidentConfig["IncidentConfiguration_Grouping_GroupByCustomDetails"] = $groupConfig.groupByCustomDetails -join ', '
        }
    }

    # Flatten event grouping settings
    $eventGrouping = @{}
    if ($yamlContent.eventGroupingSettings) {
        $eventGrouping["EventGroupingSettings_AggregationKind"] = $yamlContent.eventGroupingSettings.aggregationKind
    }

    # Flatten alert details override
    $alertDetails = @{}
    if ($yamlContent.alertDetailsOverride) {
        $alertDetails["AlertDetailsOverride_AlertDescriptionFormat"] = $yamlContent.alertDetailsOverride.alertDescriptionFormat
        if ($yamlContent.alertDetailsOverride.alertDynamicProperties) {
            $i = 1
            foreach ($property in $yamlContent.alertDetailsOverride.alertDynamicProperties) {
                $alertDetails["AlertDetailsOverride_Property${i}_AlertProperty"] = $property.alertProperty
                $alertDetails["AlertDetailsOverride_Property${i}_Value"] = $property.value
                $i++
            }
        }
    }

    # Flatten custom details into comma-separated key-value pairs
    $customDetails = ""
    if ($yamlContent.customDetails) {
        $customDetailsPairs = @()
        foreach ($key in $yamlContent.customDetails.Keys) {
            $customDetailsPairs += "$($key): $($yamlContent.customDetails[$key])"
        }
        $customDetails = $customDetailsPairs -join ', '
    }

    # Convert metadata to JSON string for easier storage in CSV
    $metadataJson = ""
    if ($yamlContent.metadata) {
        $metadataJson = $yamlContent.metadata | ConvertTo-Json -Compress
    }

    # Flatten alert details override into a JSON string for easier storage in CSV
    $alertDetailsOverrideJson = ""
    if ($yamlContent.alertDetailsOverride) {
        $alertDetailsOverrideJson = $yamlContent.alertDetailsOverride | ConvertTo-Json -Compress
    }

    $friendlyName = $yamlContent.name -replace '[^\w\-\.]', '_'
    $friendlyName = $friendlyName.Substring(0, [Math]::Min($friendlyName.Length, 50))


    $rule = @{
        Id                     = $yamlContent.id
        Name                   = $yamlContent.name
        FriendlyName           = $friendlyName
        Description            = $yamlContent.description
        Type                   = $type
        Added                  = $addedDate
        Link                   = $link
        Tactics                = $yamlContent.tactics -join ', '
        RelevantTechniques     = $yamlContent.relevantTechniques -join ', '
        Severity               = $yamlContent.severity
        QueryFrequency         = $yamlContent.queryFrequency
        QueryPeriod            = $yamlContent.queryPeriod
        Query                  = $yamlContent.query
        TriggerOperator        = $yamlContent.triggerOperator
        TriggerThreshold       = $yamlContent.triggerThreshold
        SuppressionEnabled     = $yamlContent.suppressionEnabled
        SuppressionDuration    = $yamlContent.suppressionDuration
        RequiredDataConnectors = ($yamlContent.requiredDataConnectors | ForEach-Object { "$($_.connectorId): $($_.dataTypes -join ', ')" }) -join '; '
        Version                = $yamlContent.version
        EntityMappings         = $entityMappings.TrimEnd("; ")
        CustomDetails          = $customDetails
        Metadata               = $metadataJson
        AlertDetailsOverride   = $alertDetailsOverrideJson
        CurrentlyEnabled       = $currentlyEnabled
    } + $tags + $incidentConfig + $eventGrouping

    if ($isNewRule) {
        Write-Host "New rule added with Id: $($yamlContent.id)"
    }

    return $rule
}

Function Search-AzureSentinelRepo {
    param(
        [string]$repoDirectory,
        [hashtable]$existingRules
    )

    $newRulesList = @()
    $foundFiles = Get-ChildItem -Path $repoDirectory -Recurse -File -Filter *.yaml

    foreach ($foundFile in $foundFiles) {
        $rule = Process-YamlFile -filePath $foundFile.FullName -existingRules $existingRules
        if ($null -ne $rule) {
            $newRulesList += $rule
        }
    }

    return $newRulesList
}

Function Export-RulesToCsv {
    param(
        [array]$rulesList,
        [string]$csvPath
    )

    if ($rulesList.Count -eq 0) {
        Write-Host "No valid rules found to export. Skipping CSV export."
        return
    }

    $csvData = $rulesList | ForEach-Object {
        [PSCustomObject]$_
    }

    $csvData | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "$($rulesList.Count) rules exported to $csvPath"
}

Function Import-ExistingRules {
    param(
        [string]$csvPath
    )

    if (-not (Test-Path $csvPath)) {
        return @{}
    }

    $csvContent = Import-Csv -Path $csvPath
    $existingRules = @{}

    foreach ($rule in $csvContent) {
        $existingRules[$rule.Id] = $rule
    }

    return $existingRules
}

# Ensure the Azure-Sentinel directory exists and is up-to-date
if (Test-Path $TempFolder) {
    Push-Location $TempFolder
    git pull
    Pop-Location
}
else {
    git clone https://github.com/Azure/Azure-Sentinel.git $TempFolder
}

# Import existing rules from the CSV if it exists
$existingRules = Import-ExistingRules -csvPath $OutputCsv

# Search the Azure Sentinel GitHub repository
$newRulesList = Search-AzureSentinelRepo -repoDirectory $TempFolder -existingRules $existingRules

# Export the rules to a CSV file
Export-RulesToCsv -rulesList $newRulesList -csvPath $OutputCsv

# TODO: add a check to see if the outputfile has been created already. If it has been created, we need to ensure a way to compare versions of the rules. If the version is unchanged, proceed to the next rule.
# TODO: Filter out the: "C:\temp\Azure-Sentinel\.script\tests\yamlFileValidatorTest\invalidFile.yaml"