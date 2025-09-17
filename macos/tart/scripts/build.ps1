#!/usr/bin/env pwsh

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("base", "maui", "ci")]
    [string]$ImageType,

    [string]$MacOSVersion = "sequoia",
    [string]$DotnetChannel = "10.0",
    [string]$XcodeVersion = "16.4",
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

$scriptDir = Split-Path -Parent $PSScriptRoot
$templatesDir = Join-Path $scriptDir "templates"
$configDir = Join-Path $scriptDir "config"

# Load configuration
$configFile = Join-Path $configDir "variables.json"
if (Test-Path $configFile) {
    $config = Get-Content $configFile | ConvertFrom-Json
} else {
    $config = @{}
}

# Set default image name if not provided
if (-not $ImageName) {
    $suffix = if ($Registry) { "" } else { "-$MacOSVersion" }
    $ImageName = switch ($ImageType) {
        "base" { "maui-base$suffix" }
        "maui" { "maui-dev$suffix" }
        "ci" { "maui-ci$suffix" }
    }
}

# Set base image for layered builds
if (-not $BaseImage) {
    $BaseImage = switch ($ImageType) {
        "base" { "ghcr.io/cirruslabs/macos-$MacOSVersion-base:latest" }
        "maui" { "maui-base-$MacOSVersion" }
        "ci" { "maui-dev-$MacOSVersion" }
    }
}

Write-Host "Building Tart VM Image"
Write-Host "===================="
Write-Host "Image Type: $ImageType"
Write-Host "macOS Version: $MacOSVersion"
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
        $varArgs += "-var", "$key=$($Variables[$key])"
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