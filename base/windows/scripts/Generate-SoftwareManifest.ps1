#!/usr/bin/env pwsh
# Script to generate machine-readable JSON software manifest for Windows Docker images

param(
    [string]$OutputFile = "C:\ProgramData\installed-software.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "Generating JSON software manifest..."

$manifest = @{
    manifestVersion = "1.0"
    imageType = "maui-docker-development"
    generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    operatingSystem = @{}
    dotnet = @{}
    android = @{}
    java = @{}
    tools = @{}
    environmentVariables = @{}
}

# Operating System Information
try {
    $osInfo = Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx, OSArchitecture
    $manifest.operatingSystem = @{
        productName = $osInfo.WindowsProductName
        version = $osInfo.WindowsVersion
        buildLab = $osInfo.WindowsBuildLabEx
        architecture = $osInfo.OSArchitecture
    }
} catch {
    $manifest.operatingSystem = @{
        productName = "Windows Server"
        version = "unknown"
        buildLab = "unknown"
        architecture = [System.Environment]::Is64BitOperatingSystem ? "64-bit" : "32-bit"
    }
}

# .NET Information
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    try {
        $dotnetVersion = dotnet --version 2>$null
        $manifest.dotnet.version = $dotnetVersion

        # SDKs
        $sdks = @()
        $sdkList = dotnet --list-sdks 2>$null
        foreach ($sdk in $sdkList) {
            if ($sdk -match '^(\S+)\s+\[(.+)\]') {
                $sdks += @{
                    version = $matches[1]
                    path = $matches[2]
                }
            }
        }
        $manifest.dotnet.sdks = $sdks

        # Runtimes
        $runtimes = @()
        $runtimeList = dotnet --list-runtimes 2>$null
        foreach ($runtime in $runtimeList) {
            if ($runtime -match '^(\S+)\s+(\S+)') {
                $runtimes += @{
                    name = $matches[1]
                    version = $matches[2]
                }
            }
        }
        $manifest.dotnet.runtimes = $runtimes

        # Workloads
        $workloads = @()
        $workloadList = dotnet workload list 2>$null | Select-Object -Skip 2
        foreach ($workload in $workloadList) {
            if ($workload -match '^\s*(\S+)') {
                $name = $matches[1]
                if ($name -ne "Installed" -and $name -ne "Use") {
                    $workloads += $name
                }
            }
        }
        $manifest.dotnet.workloads = $workloads

        # Global tools
        $globalTools = @()
        $toolList = dotnet tool list -g 2>$null | Select-Object -Skip 2
        foreach ($tool in $toolList) {
            if ($tool -match '^\s*(\S+)\s+(\S+)') {
                $globalTools += @{
                    name = $matches[1]
                    version = $matches[2]
                }
            }
        }
        $manifest.dotnet.globalTools = $globalTools
    } catch {
        Write-Warning ".NET information collection failed: $_"
    }
}

# Android SDK Information
$androidHome = $env:ANDROID_HOME
if ($androidHome -and (Test-Path $androidHome)) {
    $manifest.android.sdkRoot = $androidHome

    if (Get-Command android -ErrorAction SilentlyContinue) {
        try {
            # Get installed packages using android tool
            $installedJson = android sdk list --installed --format=json 2>$null | ConvertFrom-Json

            $platforms = @()
            $buildTools = @()

            foreach ($pkg in $installedJson.installed) {
                if ($pkg.path -like "platforms;*") {
                    $platforms += $pkg.path
                }
                if ($pkg.path -like "build-tools;*") {
                    $buildTools += $pkg.path
                }
            }

            $manifest.android.platforms = $platforms
            $manifest.android.buildTools = $buildTools
        } catch {
            $manifest.android.platforms = @()
            $manifest.android.buildTools = @()
        }
    } else {
        $manifest.android.platforms = @()
        $manifest.android.buildTools = @()
    }
} else {
    $manifest.android.sdkRoot = $null
    $manifest.android.platforms = @()
    $manifest.android.buildTools = @()
}

# Java Information
if (Get-Command java -ErrorAction SilentlyContinue) {
    try {
        $javaVersionOutput = java -version 2>&1 | Select-Object -First 1
        if ($javaVersionOutput -match 'version "([^"]+)"') {
            $manifest.java.version = $matches[1]
        }
        $manifest.java.home = $env:JAVA_HOME
    } catch {
        $manifest.java.version = $null
        $manifest.java.home = $null
    }
} else {
    $manifest.java.version = $null
    $manifest.java.home = $null
}

# Tools
$toolCommands = @{
    'git' = { git --version 2>$null }
    'choco' = { choco --version 2>$null }
    'pwsh' = { $PSVersionTable.PSVersion.ToString() }
}

foreach ($tool in $toolCommands.Keys) {
    try {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            $version = & $toolCommands[$tool]
            if ($version) {
                $manifest.tools[$tool] = $version.ToString().Trim()
            }
        }
    } catch {
        # Tool not available or version check failed
    }
}

# Environment Variables
$manifest.environmentVariables = @{
    ANDROID_HOME = $env:ANDROID_HOME
    ANDROID_SDK_HOME = $env:ANDROID_SDK_HOME
    JAVA_HOME = $env:JAVA_HOME
}

# Convert to JSON and save
$jsonOutput = $manifest | ConvertTo-Json -Depth 10

# Ensure output directory exists
$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write to file
$jsonOutput | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "JSON software manifest generated: $OutputFile"
