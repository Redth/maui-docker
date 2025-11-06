#!/usr/bin/env pwsh
# Script to generate CycloneDX 1.6 format Software Bill of Materials (SBOM)
# Converts the machine-readable JSON software manifest to CycloneDX format
# Windows Docker version

param(
    [string]$SourceJson = "C:\ProgramData\installed-software.json",
    [string]$OutputFile = "C:\ProgramData\installed-software.cdx.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "Generating CycloneDX 1.6 SBOM from $SourceJson..."

# Check if source JSON exists
if (-not (Test-Path $SourceJson)) {
    Write-Error "Source manifest not found: $SourceJson"
    Write-Error "Please run Generate-SoftwareManifest.ps1 first"
    exit 1
}

# Read source JSON
$source = Get-Content $SourceJson -Raw | ConvertFrom-Json

# Extract key information
$imageType = if ($source.imageType) { $source.imageType } else { "maui-docker-development" }
$generatedAt = if ($source.generatedAt) { $source.generatedAt } else { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
$osName = if ($source.operatingSystem.productName) { $source.operatingSystem.productName } else { "Windows" }
$osVersion = if ($source.operatingSystem.version) { $source.operatingSystem.version } else { "unknown" }
$osBuild = if ($source.operatingSystem.buildLab) { $source.operatingSystem.buildLab } else { "" }
$architecture = if ($source.operatingSystem.architecture) { $source.operatingSystem.architecture } else { "unknown" }

# Generate BOM metadata
$bomName = "maui-windows-docker-image"
$bomVersion = "1.0"

# Generate UUID for serial number
$uuidInput = "$bomName-$generatedAt"
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($uuidInput))
$bomUuid = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
$bomUuid = "$($bomUuid.Substring(0,8))-$($bomUuid.Substring(8,4))-$($bomUuid.Substring(12,4))-$($bomUuid.Substring(16,4))-$($bomUuid.Substring(20,12))"

# Build CycloneDX document
$cdx = [ordered]@{
    '$schema' = "http://cyclonedx.org/schema/bom-1.6.schema.json"
    bomFormat = "CycloneDX"
    specVersion = "1.6"
    serialNumber = "urn:uuid:$bomUuid"
    version = 1
    metadata = @{
        timestamp = $generatedAt
        tools = @(
            @{
                vendor = "MAUI Development Environment"
                name = "maui-docker-manifest-generator"
                version = "1.0"
            }
        )
        component = @{
            type = "container"
            'bom-ref' = "pkg:oci/$bomName@$bomVersion"
            name = $bomName
            version = $bomVersion
            description = "MAUI Windows Docker development environment with .NET, Android SDK, and development tools"
        }
    }
    components = @()
    dependencies = @()
}

# Helper function to add a component
function Add-Component {
    param(
        [string]$BomRef,
        [string]$Type,
        [string]$Name,
        [string]$Version,
        [string]$Supplier = "",
        [string]$Description = ""
    )

    $component = [ordered]@{
        type = $Type
        'bom-ref' = $BomRef
        name = $Name
        version = $Version
    }

    if ($Supplier) {
        $component.supplier = @{ name = $Supplier }
    }

    if ($Description) {
        $component.description = $Description
    }

    $script:cdx.components += $component
}

# Add Windows as operating-system component
$osDesc = "$osName $osVersion"
if ($osBuild) { $osDesc += " (build $osBuild)" }
$osDesc += ", architecture $architecture"
$osRef = "pkg:generic/windows@$osVersion"
Add-Component -BomRef $osRef -Type "operating-system" -Name $osName -Version $osVersion -Supplier "Microsoft Corporation" -Description $osDesc

# Add Java/JDK
if ($source.java.version) {
    Add-Component -BomRef "pkg:generic/msopenjdk@$($source.java.version)" -Type "application" -Name "Microsoft OpenJDK" -Version $source.java.version -Supplier "Microsoft Corporation" -Description "Microsoft Build of OpenJDK"
}

# Add .NET SDK
if ($source.dotnet.version) {
    Add-Component -BomRef "pkg:nuget/Microsoft.NET.Sdk@$($source.dotnet.version)" -Type "framework" -Name "dotnet-sdk" -Version $source.dotnet.version -Supplier "Microsoft Corporation" -Description ".NET SDK"
}

# Add .NET Workloads
if ($source.dotnet.workloads) {
    foreach ($workload in $source.dotnet.workloads) {
        $workloadName = "dotnet-workload-$workload"
        Add-Component -BomRef "pkg:nuget/$workloadName@installed" -Type "framework" -Name $workloadName -Version "installed" -Supplier "Microsoft Corporation" -Description ".NET $workload workload"
    }
}

# Add .NET Global Tools
if ($source.dotnet.globalTools) {
    foreach ($tool in $source.dotnet.globalTools) {
        Add-Component -BomRef "pkg:nuget/$($tool.name)@$($tool.version)" -Type "application" -Name $tool.name -Version $tool.version -Description ".NET global tool"
    }
}

# Add Android SDK packages
if ($source.android.platforms) {
    foreach ($platform in $source.android.platforms) {
        $apiLevel = $platform -replace 'platforms;android-', ''
        Add-Component -BomRef "pkg:generic/android-platform@$apiLevel" -Type "framework" -Name $platform -Version $apiLevel -Supplier "Google LLC" -Description "Android SDK Platform"
    }
}

if ($source.android.buildTools) {
    foreach ($buildTool in $source.android.buildTools) {
        $version = $buildTool -replace 'build-tools;', ''
        Add-Component -BomRef "pkg:generic/android-build-tools@$version" -Type "library" -Name $buildTool -Version $version -Supplier "Google LLC" -Description "Android SDK Build Tools"
    }
}

# Add tools
if ($source.tools) {
    foreach ($toolName in $source.tools.PSObject.Properties.Name) {
        $toolVersion = $source.tools.$toolName
        if ($toolVersion) {
            Add-Component -BomRef "pkg:generic/$toolName@$toolVersion" -Type "application" -Name $toolName -Version $toolVersion
        }
    }
}

# Add dependencies
$cdx.dependencies += @{
    ref = "pkg:oci/$bomName@$bomVersion"
    dependsOn = @($osRef)
}

# Convert to JSON and save
$jsonOutput = $cdx | ConvertTo-Json -Depth 10

# Ensure output directory exists
$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write to file
$jsonOutput | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "CycloneDX 1.6 SBOM generated: $OutputFile"
Write-Host "BOM: $bomName version $bomVersion"
Write-Host "Serial Number: urn:uuid:$bomUuid"
