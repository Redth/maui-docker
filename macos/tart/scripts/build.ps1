#!/usr/bin/env pwsh

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("maui", "ci")]
    [string]$ImageType,

    [ValidateNotNullOrEmpty()]
    [string]$MacOSVersion = "sequoia",

    [ValidateSet("9.0", "10.0")]
    [string]$DotnetChannel = "10.0",

    [string]$WorkloadSetVersion = "",
    [string]$XcodeVersion = "",
    [string]$ImageName = "",
    [string]$BaseImage = "",
    [string]$Registry = "",
    [int]$CPUCount = 4,
    [int]$MemoryGB = 8,
    [switch]$Push,
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Directory locations
$scriptDir = Split-Path -Parent $PSScriptRoot
$templatesDir = Join-Path $scriptDir "templates"
$configDir = Join-Path $scriptDir "config"

# Load configuration
$variablesFile = Join-Path $configDir "variables.json"
if (Test-Path $variablesFile) {
    $config = Get-Content $variablesFile -Raw | ConvertFrom-Json
} else {
    $config = @{}
}

$matrixFile = Join-Path $configDir "platform-matrix.json"
if (Test-Path $matrixFile) {
    $script:PlatformMatrix = Get-Content $matrixFile -Raw | ConvertFrom-Json
} else {
    throw "Platform mapping file not found: $matrixFile"
}

# Version mapping and validation
function Get-PlatformMatrixEntry {
    param(
        [pscustomobject]$Section,
        [string]$Key
    )

    if (-not $Section -or -not $Key) {
        return $null
    }

    $property = $Section.PSObject.Properties | Where-Object { $_.Name -eq $Key } | Select-Object -First 1
    return $property.Value
}

function Get-MacOSVersionInfo {
    param([string]$MacOSVersion)

    $macOSInfo = Get-PlatformMatrixEntry -Section $script:PlatformMatrix.MacOSVersions -Key $MacOSVersion

    if ($macOSInfo) {
        return $macOSInfo
    }

    return [pscustomobject]@{
        FullName = "macOS $MacOSVersion"
        MinXcodeVersion = ""
        RecommendedXcodeVersion = ""
    }
}

function Get-DotnetChannelInfo {
    param([string]$DotnetChannel)

    $channelInfo = Get-PlatformMatrixEntry -Section $script:PlatformMatrix.DotnetChannels -Key $DotnetChannel

    if (-not $channelInfo) {
        $availableChannels = @()
        if ($script:PlatformMatrix.DotnetChannels) {
            $availableChannels = $script:PlatformMatrix.DotnetChannels.PSObject.Properties.Name
        }
        throw "Unsupported .NET channel: $DotnetChannel. Supported channels: $($availableChannels -join ', ')"
    }

    return $channelInfo
}

function Get-DotnetChannelTarget {
    param(
        [pscustomobject]$DotnetInfo,
        [string]$MacOSVersion
    )

    if (-not $DotnetInfo -or -not $DotnetInfo.Targets) {
        return $null
    }

    if ($MacOSVersion) {
        $match = $DotnetInfo.Targets | Where-Object { $_.MacOSVersion -eq $MacOSVersion } | Select-Object -First 1
        if ($match) {
            return $match
        }
    }

    return $DotnetInfo.Targets | Select-Object -First 1
}

function Test-VersionCompatibility {
    param([string]$MacOSVersion, [string]$DotnetChannel)

    $dotnetInfo = Get-DotnetChannelInfo -DotnetChannel $DotnetChannel

    # Check minimum macOS version for .NET
    $macOSVersionOrder = @('monterey', 'ventura', 'sonoma', 'sequoia', 'tahoe')
    $normalizedMacOSVersion = $MacOSVersion.ToLowerInvariant()
    $currentIndex = $macOSVersionOrder.IndexOf($normalizedMacOSVersion)
    $minIndex = $macOSVersionOrder.IndexOf($dotnetInfo.MinMacOSVersion)

    if ($currentIndex -eq -1) {
        Write-Verbose "Skipping compatibility check for unrecognized macOS version '$MacOSVersion'."
        return $true
    }

    if ($currentIndex -lt $minIndex) {
        Write-Warning ".NET $DotnetChannel requires at least $($dotnetInfo.MinMacOSVersion), but you selected $MacOSVersion"
        return $false
    }

    return $true
}
if ($MacOSVersion) {
    $MacOSVersion = $MacOSVersion.Trim().ToLowerInvariant()
}

if ($DotnetChannel) {
    $DotnetChannel = $DotnetChannel.Trim()
}

$dotnetInfo = $null
if ($DotnetChannel) {
    $dotnetInfo = Get-DotnetChannelInfo -DotnetChannel $DotnetChannel
}

$macOSInfo = $null
if ($MacOSVersion) {
    $macOSInfo = Get-MacOSVersionInfo -MacOSVersion $MacOSVersion
}

if (-not $PSBoundParameters.ContainsKey('XcodeVersion') -and -not $XcodeVersion) {
    $target = Get-DotnetChannelTarget -DotnetInfo $dotnetInfo -MacOSVersion $MacOSVersion
    if ($target) {
        $XcodeVersion = $target.XcodeVersion
    } elseif ($macOSInfo -and $macOSInfo.RecommendedXcodeVersion) {
        $XcodeVersion = $macOSInfo.RecommendedXcodeVersion
    } else {
        throw 'Xcode version is required when no platform matrix recommendation is available.'
    }
}

if ($MacOSVersion -and $DotnetChannel) {
    [void](Test-VersionCompatibility -MacOSVersion $MacOSVersion -DotnetChannel $DotnetChannel)
}

# Set default image name if not provided
if (-not $ImageName) {
    $suffix = if ($Registry) { "" } else { "-$MacOSVersion" }
    $ImageName = switch ($ImageType) {
        "maui" { "maui-dev$suffix" }
        "ci" { "maui-ci$suffix" }
    }
}

# Set base image for layered builds
if (-not $BaseImage) {
    $BaseImage = switch ($ImageType) {
        "maui" {
            if (-not $XcodeVersion) {
                throw 'Xcode version is required for maui image builds.'
            }
            "ghcr.io/cirruslabs/macos-$MacOSVersion-xcode:$XcodeVersion"
        }
        "ci" { "maui-dev-$MacOSVersion" }
    }
}

Write-Host "Building Tart VM Image"
Write-Host "===================="
Write-Host "Image Type: $ImageType"
Write-Host "macOS Version: $MacOSVersion"
Write-Host ".NET Channel: $DotnetChannel"
if ($XcodeVersion) {
    Write-Host "Xcode Version: $XcodeVersion"
}
Write-Host "Image Name: $ImageName"
Write-Host "Base Image: $BaseImage"
Write-Host "CPU Count: $CPUCount"
Write-Host "Memory: ${MemoryGB}GB"
Write-Host "Dry Run: $($DryRun.IsPresent)"
Write-Host ""

# Check prerequisites
function Test-Prerequisites {
    $missing = @()

    if (-not (Get-Command tart -ErrorAction SilentlyContinue)) {
        $missing += "tart (install with: brew install cirruslabs/cli/tart)"
    }

    if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
        $missing += "packer (install with: brew install packer)"
    }

    if ($missing.Count -gt 0) {
        Write-Error "Missing prerequisites:`n$($missing -join "`n")"
        exit 1
    }
}

function Start-TartBuild {
    param(
        [string]$TemplatePath,
        [hashtable]$Variables
    )

    if (-not (Test-Path $TemplatePath)) {
        throw "Template not found: $TemplatePath"
    }

    $varArgs = @()
    foreach ($key in $Variables.Keys) {
        $value = $Variables[$key]
        # Convert complex objects to JSON for Packer
        if ($value -is [hashtable] -or $value -is [PSCustomObject]) {
            $jsonValue = $value | ConvertTo-Json -Compress
            $varArgs += "-var", "$key=$jsonValue"
        } else {
            $varArgs += "-var", "$key=$value"
        }
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would run: packer build $($varArgs -join ' ') $TemplatePath"
        return
    }

    Write-Host "Running Packer build..."
    & packer build @varArgs $TemplatePath

    if ($LASTEXITCODE -ne 0) {
        throw "Packer build failed with exit code $LASTEXITCODE"
    }
}

function Push-TartImage {
    param([string]$ImageName, [string]$Registry)

    if (-not $Registry) {
        Write-Host "No registry specified, skipping push"
        return
    }

    $fullImageName = "$Registry/$ImageName"

    if ($DryRun) {
        Write-Host "[DryRun] Would push image to: $fullImageName"
        return
    }

    Write-Host "Pushing image to registry..."
    & tart push $ImageName $fullImageName

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push image to registry"
    }
}

function Test-ImageExists {
    param([string]$ImageName)

    $images = & tart list | Out-String
    return $images -match [regex]::Escape($ImageName)
}

# Main execution
try {
    Test-Prerequisites

    # Check if image already exists
    if ((Test-ImageExists $ImageName) -and -not $Force) {
        Write-Warning "Image '$ImageName' already exists. Use -Force to rebuild."
        exit 1
    }

    # Prepare template path
    $templateFile = "$ImageType.pkr.hcl"
    $templatePath = Join-Path $templatesDir $templateFile

    # Prepare build variables
    $buildVars = @{
        "image_name" = $ImageName
        "base_image" = $BaseImage
        "macos_version" = $MacOSVersion
        "dotnet_channel" = $DotnetChannel
        "xcode_version" = $XcodeVersion
        "cpu_count" = $CPUCount
        "memory_gb" = $MemoryGB
    }

    # Add any additional variables from config file
    if ($config.PSObject.Properties) {
        foreach ($prop in $config.PSObject.Properties) {
            if (-not $buildVars.ContainsKey($prop.Name)) {
                $buildVars[$prop.Name] = $prop.Value
            }
        }
    }

    Write-Host "Build variables:"
    $buildVars.GetEnumerator() | Sort-Object Key | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
    Write-Host ""

    # Build the image
    Start-TartBuild -TemplatePath $templatePath -Variables $buildVars

    # Push to registry if requested
    if ($Push) {
        Push-TartImage -ImageName $ImageName -Registry $Registry
    }

    Write-Host ""
    Write-Host "✅ Build completed successfully!"
    Write-Host "Image name: $ImageName"

    if (-not $DryRun) {
        Write-Host ""
        Write-Host "To run the VM:"
        Write-Host "  tart run $ImageName"
        Write-Host ""
        Write-Host "To run with directory mounting:"
        Write-Host "  tart run $ImageName --dir project:/path/to/your/project"
    }

} catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
