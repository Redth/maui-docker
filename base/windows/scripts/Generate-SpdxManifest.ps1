#!/usr/bin/env pwsh
# Script to generate SPDX 2.3 format Software Bill of Materials (SBOM)
# Converts the machine-readable JSON software manifest to SPDX format
# Windows Docker version

param(
    [string]$SourceJson = "C:\ProgramData\installed-software.json",
    [string]$OutputFile = "C:\ProgramData\installed-software.spdx.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "Generating SPDX 2.3 SBOM from $SourceJson..."

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

# Generate document name
$docName = "maui-windows-docker-image"
$docVersion = "1.0"

# Generate UUID for document namespace
$uuidInput = "$docName-$generatedAt"
$md5 = [System.Security.Cryptography.MD5]::Create()
$hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($uuidInput))
$docUuid = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
$docUuid = "$($docUuid.Substring(0,8))-$($docUuid.Substring(8,4))-$($docUuid.Substring(12,4))-$($docUuid.Substring(16,4))-$($docUuid.Substring(20,12))"

# Build SPDX document
$spdx = @{
    spdxVersion = "SPDX-2.3"
    dataLicense = "CC0-1.0"
    SPDXID = "SPDXRef-DOCUMENT"
    name = $docName
    documentNamespace = "https://github.com/redth/maui-docker/spdx/$docName-$docUuid"
    creationInfo = @{
        created = $generatedAt
        creators = @(
            "Tool: maui-docker-manifest-generator",
            "Organization: MAUI Development Environment"
        )
        comment = "SBOM for MAUI Docker development environment containing .NET, Android SDK, and development tools"
    }
    comment = "Software Bill of Materials for $imageType Windows Docker image ($osName $osVersion, $architecture)"
    packages = @()
    relationships = @()
}

# Helper function to add a package
function Add-Package {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Version,
        [string]$Supplier = "NOASSERTION",
        [string]$Download = "NOASSERTION",
        [string]$Comment = ""
    )

    $package = @{
        SPDXID = "SPDXRef-Package-$Id"
        name = $Name
        versionInfo = $Version
        supplier = $Supplier
        downloadLocation = $Download
        filesAnalyzed = $false
        licenseConcluded = "NOASSERTION"
        licenseDeclared = "NOASSERTION"
        copyrightText = "NOASSERTION"
    }

    if ($Comment) {
        $package.comment = $Comment
    }

    $script:spdx.packages += $package
    return "SPDXRef-Package-$Id"
}

# Add Windows as root package
$osComment = "$osName $osVersion"
if ($osBuild) { $osComment += " (build $osBuild)" }
$osComment += ", architecture $architecture"
$osId = Add-Package -Id "Windows" -Name $osName -Version $osVersion -Supplier "Organization: Microsoft Corporation" -Comment $osComment

# Add Java/JDK
if ($source.java.version) {
    $javaComment = "Microsoft OpenJDK"
    if ($source.java.home) {
        $javaComment += " ($($source.java.home))"
    }
    Add-Package -Id "msopenjdk" -Name "Microsoft OpenJDK" -Version $source.java.version -Supplier "Organization: Microsoft Corporation" -Download "https://www.microsoft.com/openjdk" -Comment $javaComment | Out-Null
}

# Add .NET SDK
if ($source.dotnet.version) {
    Add-Package -Id "dotnet-sdk" -Name "dotnet-sdk" -Version $source.dotnet.version -Supplier "Organization: Microsoft Corporation" -Download "https://dot.net/" | Out-Null
}

# Add .NET Workloads
if ($source.dotnet.workloads) {
    foreach ($workload in $source.dotnet.workloads) {
        Add-Package -Id "workload-$workload" -Name "dotnet-workload-$workload" -Version "installed" -Supplier "Organization: Microsoft Corporation" | Out-Null
    }
}

# Add .NET Global Tools
if ($source.dotnet.globalTools) {
    foreach ($tool in $source.dotnet.globalTools) {
        $toolId = $tool.name.ToLower().Replace(".", "-")
        Add-Package -Id $toolId -Name $tool.name -Version $tool.version | Out-Null
    }
}

# Add Android SDK packages
if ($source.android.platforms) {
    foreach ($platform in $source.android.platforms) {
        $platformId = $platform.ToLower().Replace(";", "-")
        Add-Package -Id $platformId -Name $platform -Version "installed" -Supplier "Organization: Google LLC" -Download "https://developer.android.com/studio" | Out-Null
    }
}

if ($source.android.buildTools) {
    foreach ($buildTool in $source.android.buildTools) {
        $buildToolId = $buildTool.ToLower().Replace(";", "-")
        $version = $buildTool -replace 'build-tools;', ''
        Add-Package -Id $buildToolId -Name $buildTool -Version $version -Supplier "Organization: Google LLC" -Download "https://developer.android.com/studio" | Out-Null
    }
}

# Add tools
if ($source.tools) {
    foreach ($toolName in $source.tools.PSObject.Properties.Name) {
        $toolVersion = $source.tools.$toolName
        if ($toolVersion) {
            Add-Package -Id $toolName -Name $toolName -Version $toolVersion | Out-Null
        }
    }
}

# Add relationships
$spdx.relationships += @{
    spdxElementId = "SPDXRef-DOCUMENT"
    relationshipType = "DESCRIBES"
    relatedSpdxElement = $osId
}

# Add CONTAINS relationships
foreach ($package in $spdx.packages) {
    if ($package.SPDXID -ne $osId) {
        $spdx.relationships += @{
            spdxElementId = $osId
            relationshipType = "CONTAINS"
            relatedSpdxElement = $package.SPDXID
        }
    }
}

# Convert to JSON and save
$jsonOutput = $spdx | ConvertTo-Json -Depth 10

# Ensure output directory exists
$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write to file
$jsonOutput | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "SPDX 2.3 SBOM generated: $OutputFile"
Write-Host "Document: $docName"
Write-Host "Namespace: https://github.com/redth/maui-docker/spdx/$docName-$docUuid"
