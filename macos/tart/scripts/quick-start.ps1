#!/usr/bin/env pwsh

Param(
    [ValidateSet("base", "maui", "ci", "all")]
    [string]$BuildType = "maui",
    [string]$MacOSVersion = "sequoia",
    [string]$DotnetChannel = "10.0",
    [switch]$Test,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "MAUI Tart VM Quick Start"
Write-Host "========================"
Write-Host "Build Type: $BuildType"
Write-Host "macOS Version: $MacOSVersion"
Write-Host ".NET Channel: $DotnetChannel"
Write-Host "Dry Run: $($DryRun.IsPresent)"
Write-Host ""

$scriptDir = Split-Path -Parent $PSScriptRoot

function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..."

    $missing = @()

    if (-not (Get-Command tart -ErrorAction SilentlyContinue)) {
        $missing += "tart"
        Write-Host "❌ Tart not found"
    } else {
        Write-Host "✅ Tart found"
    }

    if (-not (Get-Command packer -ErrorAction SilentlyContinue)) {
        $missing += "packer"
        Write-Host "❌ Packer not found"
    } else {
        Write-Host "✅ Packer found"
    }

    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "Missing prerequisites. Install with:"
        foreach ($tool in $missing) {
            switch ($tool) {
                "tart" { Write-Host "  brew install cirruslabs/cli/tart" }
                "packer" { Write-Host "  brew install packer" }
            }
        }
        throw "Prerequisites not met"
    }

    Write-Host "✅ All prerequisites satisfied"
    Write-Host ""
}

function Build-Image {
    param([string]$ImageType, [string]$MacOSVersion, [string]$DotnetChannel, [bool]$DryRun)

    Write-Host "🔨 Building $ImageType image..."

    $buildArgs = @(
        "-ImageType", $ImageType
        "-MacOSVersion", $MacOSVersion
    )

    if ($ImageType -eq "maui" -or $ImageType -eq "ci") {
        $buildArgs += "-DotnetChannel", $DotnetChannel
    }

    if ($DryRun) {
        $buildArgs += "-DryRun"
    }

    $buildScript = Join-Path $scriptDir "scripts/build.ps1"
    & pwsh $buildScript @buildArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build $ImageType image"
    }
}

function Test-Image {
    param([string]$ImageName, [string]$TestType)

    Write-Host "🧪 Testing $ImageName..."

    $testScript = Join-Path $scriptDir "scripts/test.ps1"
    & pwsh $testScript -ImageName $ImageName -TestType $TestType

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to test $ImageName"
    }
}

function Show-Usage {
    param([string]$ImageName)

    Write-Host ""
    Write-Host "🎉 Setup completed successfully!"
    Write-Host ""
    Write-Host "Your VM image is ready: $ImageName"
    Write-Host ""
    Write-Host "Quick usage examples:"
    Write-Host "  # Start the VM"
    Write-Host "  tart run $ImageName"
    Write-Host ""
    Write-Host "  # Run with your project mounted"
    Write-Host "  tart run $ImageName --dir project:/path/to/your/maui/project"
    Write-Host ""
    Write-Host "  # SSH into the running VM"
    Write-Host "  tart ip $ImageName"
    Write-Host "  ssh admin@<ip-address>"
    Write-Host ""

    if ($ImageName -like "*maui*" -or $ImageName -like "*ci*") {
        Write-Host "MAUI development commands (inside VM):"
        Write-Host "  # Access your mounted project"
        Write-Host "  cd '/Volumes/My Shared Files/project'"
        Write-Host ""
        Write-Host "  # Create a new MAUI project"
        Write-Host "  dotnet new maui -n MyApp"
        Write-Host ""
        Write-Host "  # Build and run"
        Write-Host "  dotnet build"
        Write-Host "  dotnet run"
        Write-Host ""
    }

    Write-Host "For more information, see: ./README.md"
}

# Main execution
try {
    Test-Prerequisites

    $imagesToBuild = switch ($BuildType) {
        "base" { @("base") }
        "maui" { @("base", "maui") }
        "ci" { @("base", "maui", "ci") }
        "all" { @("base", "maui", "ci") }
    }

    foreach ($imageType in $imagesToBuild) {
        Build-Image -ImageType $imageType -MacOSVersion $MacOSVersion -DotnetChannel $DotnetChannel -DryRun $DryRun.IsPresent

        if ($Test -and -not $DryRun) {
            $imageName = switch ($imageType) {
                "base" { "maui-base-$MacOSVersion" }
                "maui" { "maui-dev-$MacOSVersion" }
                "ci" { "maui-ci-$MacOSVersion" }
            }

            Test-Image -ImageName $imageName -TestType $imageType
        }
    }

    $finalImageName = switch ($BuildType) {
        "base" { "maui-base-$MacOSVersion" }
        "maui" { "maui-dev-$MacOSVersion" }
        "ci" { "maui-ci-$MacOSVersion" }
        "all" { "maui-ci-$MacOSVersion" }
    }

    if (-not $DryRun) {
        Show-Usage -ImageName $finalImageName
    } else {
        Write-Host ""
        Write-Host "✅ Dry run completed successfully!"
        Write-Host "Remove -DryRun to actually build the images."
    }

} catch {
    Write-Error "❌ Quick start failed: $($_.Exception.Message)"
    exit 1
}