#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Checks for new .NET workload set versions and determines if builds should be triggered.

.DESCRIPTION
    This script checks for the latest .NET workload set version using the Find-LatestWorkloadSet function,
    then queries Docker Hub to see if we already have builds for that version. It outputs GitHub Actions
    variables to indicate whether new builds should be triggered.

.PARAMETER DotnetVersion
    The .NET version to check for workload sets. Defaults to "9.0".

.PARAMETER DockerRepository
    The Docker repository to check for existing tags. Defaults to "redth/maui-actions-runner".

.PARAMETER TagPattern
    The tag pattern to look for. The script will replace placeholders with actual values:
    - {platform}: 'linux' or 'windows' 
    - {dotnet_version}: The .NET version (e.g., '9.0')
    - {workload_version}: The workload set version (e.g., '9.0.301.1')
    Defaults to "{platform}-dotnet{dotnet_version}-workloads{workload_version}".

.PARAMETER OutputFormat
    The output format. Use "github-actions" for GitHub Actions environment variables,
    or "object" for PowerShell object output. Defaults to "github-actions".

.EXAMPLE
    .\check-workload-updates.ps1
    
.EXAMPLE
    .\check-workload-updates.ps1 -DotnetVersion "9.0" -DockerRepository "myrepo/myimage" -OutputFormat "object"
#>

param(
    [Parameter(Position = 0)]
    [string]$DotnetVersion = "9.0",
    
    [Parameter(Position = 1)]
    [string]$DockerRepository = "redth/maui-actions-runner",
    
    [Parameter(Position = 2)]
    [string]$TagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}",
    
    [Parameter(Position = 3)]
    [ValidateSet("github-actions", "object")]
    [string]$OutputFormat = "github-actions"
)

# Import common functions
$commonFunctionsPath = Join-Path $PSScriptRoot "common-functions.ps1"
if (-not (Test-Path $commonFunctionsPath)) {
    Write-Error "Cannot find common-functions.ps1 at: $commonFunctionsPath"
    exit 1
}

. $commonFunctionsPath

function Write-GitHubOutput {
    param(
        [string]$Name,
        [string]$Value
    )
    
    if ($OutputFormat -eq "github-actions") {
        Write-Output "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }
}

function Write-HostWithPrefix {
    param([string]$Message)
    Write-Host "🔍 $Message"
}

try {
    Write-HostWithPrefix "Checking for latest .NET $DotnetVersion workload set..."
    
    # Get comprehensive workload information
    $workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -IncludeAndroid -DockerPlatform "linux/amd64"
    
    if (-not $workloadInfo) {
        Write-Error "Failed to get workload information for .NET $DotnetVersion"
        exit 1
    }
    
    $latestVersion = $workloadInfo.WorkloadSetVersion
    $dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion
    
    Write-HostWithPrefix "Latest workload set version: $latestVersion"
    Write-HostWithPrefix "Dotnet command workload set version: $dotnetCommandWorkloadSetVersion"
    
    # Create expected tag patterns for both platforms
    $linuxTag = $TagPattern -replace '\{platform\}', 'linux' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
    $windowsTag = $TagPattern -replace '\{platform\}', 'windows' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
    
    Write-HostWithPrefix "Looking for Linux tag: $linuxTag"
    Write-HostWithPrefix "Looking for Windows tag: $windowsTag"
    
    # Check existing Docker Hub tags
    Write-HostWithPrefix "Checking existing tags in Docker Hub for $DockerRepository..."
    
    $triggerBuilds = $false
    $newVersion = $false
    $errorMessage = $null
    $hasLinuxBuild = $false
    $hasWindowsBuild = $false
    $linuxTag = ""
    $windowsTag = ""
    
    try {
        # Get tags from Docker Hub API
        $dockerHubUri = "https://registry.hub.docker.com/v2/repositories/$DockerRepository/tags?page_size=100"
        Write-HostWithPrefix "Querying Docker Hub API: $dockerHubUri"
        
        $tagsResponse = Invoke-RestMethod -Uri $dockerHubUri -TimeoutSec 30
        $existingTags = $tagsResponse.results | ForEach-Object { $_.name }
        
        Write-HostWithPrefix "Found $($existingTags.Count) existing tags"
        if ($existingTags.Count -le 10) {
            Write-HostWithPrefix "Existing tags: $($existingTags -join ', ')"
        } else {
            Write-HostWithPrefix "First 10 tags: $($existingTags[0..9] -join ', ')..."
        }
        
        # Check if we already have builds for this workload set version
        $hasLinuxBuild = $existingTags -contains $linuxTag
        $hasWindowsBuild = $existingTags -contains $windowsTag
        $hasAnyBuild = $hasLinuxBuild -or $hasWindowsBuild
        
        Write-HostWithPrefix "Has Linux build for tag '$linuxTag': $hasLinuxBuild"
        Write-HostWithPrefix "Has Windows build for tag '$windowsTag': $hasWindowsBuild"
        Write-HostWithPrefix "Has any existing build: $hasAnyBuild"
        
        if (-not $hasAnyBuild) {
            Write-HostWithPrefix "✅ New workload set version found! Builds should be triggered."
            $triggerBuilds = $true
            $newVersion = $true
        } else {
            Write-HostWithPrefix "ℹ️ Workload set version $dotnetCommandWorkloadSetVersion already built. No action needed."
            if ($hasLinuxBuild -and $hasWindowsBuild) {
                Write-HostWithPrefix "   Both Linux and Windows builds exist."
            } elseif ($hasLinuxBuild) {
                Write-HostWithPrefix "   Only Linux build exists, Windows build may be needed."
            } else {
                Write-HostWithPrefix "   Only Windows build exists, Linux build may be needed."
            }
            $triggerBuilds = $false
            $newVersion = $false
        }
        
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Warning "❌ Failed to check Docker Hub tags: $errorMessage"
        Write-HostWithPrefix "🔄 Assuming we need to build (fail-safe approach)"
        $triggerBuilds = $true
        $newVersion = $true
    }
    
    # Create result object
    $result = [PSCustomObject]@{
        LatestVersion = $latestVersion
        DotnetCommandWorkloadSetVersion = $dotnetCommandWorkloadSetVersion
        LinuxTag = $linuxTag
        WindowsTag = $windowsTag
        HasLinuxBuild = $hasLinuxBuild
        HasWindowsBuild = $hasWindowsBuild
        TriggerBuilds = $triggerBuilds
        NewVersion = $newVersion
        ErrorMessage = $errorMessage
        DockerRepository = $DockerRepository
        DotnetVersion = $DotnetVersion
    }
    
    # Output results
    if ($OutputFormat -eq "github-actions") {
        Write-GitHubOutput "trigger-builds" $triggerBuilds.ToString().ToLower()
        Write-GitHubOutput "new-version" $newVersion.ToString().ToLower()
        Write-GitHubOutput "workload-set-version" $latestVersion
        Write-GitHubOutput "dotnet-command-workload-set-version" $dotnetCommandWorkloadSetVersion
        Write-GitHubOutput "linux-tag" $linuxTag
        Write-GitHubOutput "windows-tag" $windowsTag
        
        Write-HostWithPrefix "GitHub Actions outputs set:"
        Write-HostWithPrefix "  trigger-builds: $($triggerBuilds.ToString().ToLower())"
        Write-HostWithPrefix "  new-version: $($newVersion.ToString().ToLower())"
        Write-HostWithPrefix "  workload-set-version: $latestVersion"
        Write-HostWithPrefix "  dotnet-command-workload-set-version: $dotnetCommandWorkloadSetVersion"
        Write-HostWithPrefix "  linux-tag: $linuxTag"
        Write-HostWithPrefix "  windows-tag: $windowsTag"
    } else {
        return $result
    }
    
} catch {
    Write-Error "❌ Script failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
