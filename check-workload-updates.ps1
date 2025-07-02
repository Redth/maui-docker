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

.PARAMETER TestDockerRepository
    The test Docker repository to check for existing tags. Defaults to "redth/maui-testing".

.PARAMETER TagPattern
    The tag pattern to look for. The script will replace placeholders with actual values:
    - {platform}: 'linux' or 'windows' 
    - {dotnet_version}: The .NET version (e.g., '9.0')
    - {workload_version}: The workload set version (e.g., '9.0.301.1')
    Defaults to "{platform}-dotnet{dotnet_version}-workloads{workload_version}".

.PARAMETER TestTagPattern
    The test tag pattern to look for. Includes Android API level support:
    - {platform}: 'appium-emulator-linux'
    - {dotnet_version}: The .NET version (e.g., '9.0')
    - {workload_version}: The workload set version (e.g., '9.0.301.1')
    - {api_level}: Android API level (e.g., '35')
    Defaults to "{platform}-dotnet{dotnet_version}-workloads{workload_version}-android{api_level}".

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
    [string]$TestDockerRepository = "redth/maui-testing",
    
    [Parameter(Position = 3)]
    [string]$TagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}",
    
    [Parameter(Position = 4)]
    [string]$TestTagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}-android{api_level}",
    
    [Parameter(Position = 5)]
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
        if ($env:GITHUB_OUTPUT) {
            Write-Output "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        } else {
            Write-Host "::set-output name=$Name::$Value"
        }
    }
}

function Write-HostWithPrefix {
    param([string]$Message)
    Write-Host "🔍 $Message"
}

# Function to check for existing test builds with Android API levels
function Test-TestRepositoryBuilds {
    param(
        [string]$Repository,
        [string]$TagPattern,
        [string]$DotnetVersion,
        [string]$WorkloadVersion
    )
    
    Write-HostWithPrefix "Checking test repository: $Repository"
    
    try {
        # Get tags from Docker Hub API for test repository
        $dockerHubUri = "https://registry.hub.docker.com/v2/repositories/$Repository/tags?page_size=100"
        Write-HostWithPrefix "Querying Docker Hub API for test repo: $dockerHubUri"
        
        $tagsResponse = Invoke-RestMethod -Uri $dockerHubUri -TimeoutSec 30
        $existingTags = $tagsResponse.results | ForEach-Object { $_.name }
        
        Write-HostWithPrefix "Found $($existingTags.Count) test repository tags"
        
        # Create test tag patterns for common API levels (we check for any Android API level)
        # The test tag pattern is: appium-emulator-linux-dotnet{version}-workloads{workload}-android{api}
        $testPlatform = "appium-emulator-linux"
        $testTagPattern = $TagPattern -replace '\{platform\}', $testPlatform -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $WorkloadVersion
        
        # Check if any tag matches the pattern with any API level
        $matchingTags = $existingTags | Where-Object { 
            $_ -match "^$($testTagPattern -replace '\{api_level\}', '\d+')" 
        }
        
        $hasTestBuilds = $matchingTags.Count -gt 0
        
        Write-HostWithPrefix "Test tag pattern (with API level): $($testTagPattern -replace '\{api_level\}', 'XX')"
        Write-HostWithPrefix "Matching test tags found: $($matchingTags.Count)"
        if ($matchingTags.Count -gt 0 -and $matchingTags.Count -le 5) {
            Write-HostWithPrefix "Sample matching tags: $($matchingTags -join ', ')"
        } elseif ($matchingTags.Count -gt 5) {
            Write-HostWithPrefix "Sample matching tags: $($matchingTags[0..4] -join ', ')..."
        }
        
        return $hasTestBuilds
        
    } catch {
        Write-HostWithPrefix "Warning: Could not check test repository $Repository - $($_.Exception.Message)"
        return $false
    }
}

try {
    Write-HostWithPrefix "Checking for latest .NET $DotnetVersion workload set..."
    
    # Initialize variables
    $triggerBuilds = $false
    $newVersion = $false
    $errorMessage = $null
    $hasLinuxBuild = $false
    $hasWindowsBuild = $false
    $hasTestBuilds = $false
    $hasWindowsBuild = $false
    $linuxTag = ""
    $windowsTag = ""
    $latestVersion = ""
    $dotnetCommandWorkloadSetVersion = ""
    
    # Get comprehensive workload information
    # First try the simple approach
    Write-HostWithPrefix "Trying to find latest workload set..."
    $latestWorkloadSet = Find-LatestWorkloadSet -DotnetVersion $DotnetVersion
    
    if ($latestWorkloadSet) {
        $latestVersion = $latestWorkloadSet.version
        $dotnetCommandWorkloadSetVersion = Convert-ToWorkloadVersion -NuGetVersion $latestVersion
        Write-HostWithPrefix "Using simple workload set approach"
    } else {
        Write-HostWithPrefix "Simple approach failed, trying comprehensive workload info..."
        $workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -IncludeAndroid -DockerPlatform "linux/amd64"
        
        if (-not $workloadInfo) {
            Write-Error "Failed to get workload information for .NET $DotnetVersion"
            exit 1
        }
        
        Write-HostWithPrefix "Workload info retrieved successfully"
        Write-HostWithPrefix "Available properties: $($workloadInfo.Keys -join ', ')"
        
        $latestVersion = $workloadInfo.WorkloadSetVersion
        $dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion
    }
    
    if (-not $latestVersion) {
        Write-Error "WorkloadSetVersion is null or empty in workload info"
        exit 1
    }
    
    if (-not $dotnetCommandWorkloadSetVersion) {
        Write-Error "DotnetCommandWorkloadSetVersion is null or empty in workload info"
        exit 1
    }
    
    Write-HostWithPrefix "Latest workload set version: $latestVersion"
    Write-HostWithPrefix "Dotnet command workload set version: $dotnetCommandWorkloadSetVersion"
    
    # Create expected tag patterns for both platforms
    $linuxTag = $TagPattern -replace '\{platform\}', 'linux' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
    $windowsTag = $TagPattern -replace '\{platform\}', 'windows' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
    
    Write-HostWithPrefix "Looking for Linux tag: $linuxTag"
    Write-HostWithPrefix "Looking for Windows tag: $windowsTag"
    
    # Check existing Docker Hub tags
    Write-HostWithPrefix "Checking existing tags in Docker Hub for $DockerRepository..."
    
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
        
        Write-HostWithPrefix "Has Linux build for tag '$linuxTag': $hasLinuxBuild"
        Write-HostWithPrefix "Has Windows build for tag '$windowsTag': $hasWindowsBuild"
        
        # Also check test repository for builds
        $hasTestBuilds = Test-TestRepositoryBuilds -Repository $TestDockerRepository -TagPattern $TestTagPattern -DotnetVersion $DotnetVersion -WorkloadVersion $dotnetCommandWorkloadSetVersion
        Write-HostWithPrefix "Has test builds: $hasTestBuilds"
        
        $hasAnyBuild = $hasLinuxBuild -or $hasWindowsBuild -or $hasTestBuilds
        Write-HostWithPrefix "Has any existing build (runner or test): $hasAnyBuild"
        
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
        
        # In error case, still set the tag values if we have them
        if ($latestVersion -and $dotnetCommandWorkloadSetVersion) {
            $linuxTag = $TagPattern -replace '\{platform\}', 'linux' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
            $windowsTag = $TagPattern -replace '\{platform\}', 'windows' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $dotnetCommandWorkloadSetVersion
        }
        
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
        HasTestBuilds = $hasTestBuilds
        TriggerBuilds = $triggerBuilds
        NewVersion = $newVersion
        ErrorMessage = $errorMessage
        DockerRepository = $DockerRepository
        TestDockerRepository = $TestDockerRepository
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
        Write-GitHubOutput "has-test-builds" $hasTestBuilds.ToString().ToLower()
        
        Write-HostWithPrefix "GitHub Actions outputs set:"
        Write-HostWithPrefix "  trigger-builds: $($triggerBuilds.ToString().ToLower())"
        Write-HostWithPrefix "  new-version: $($newVersion.ToString().ToLower())"
        Write-HostWithPrefix "  workload-set-version: $latestVersion"
        Write-HostWithPrefix "  dotnet-command-workload-set-version: $dotnetCommandWorkloadSetVersion"
        Write-HostWithPrefix "  linux-tag: $linuxTag"
        Write-HostWithPrefix "  windows-tag: $windowsTag"
        Write-HostWithPrefix "  has-test-builds: $($hasTestBuilds.ToString().ToLower())"
    } else {
        return $result
    }
    
} catch {
    Write-Error "❌ Script failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    
    # Set default values for output
    if (-not $latestVersion) { $latestVersion = "unknown" }
    if (-not $dotnetCommandWorkloadSetVersion) { $dotnetCommandWorkloadSetVersion = "unknown" }
    if (-not $linuxTag) { $linuxTag = "unknown" }
    if (-not $windowsTag) { $windowsTag = "unknown" }
    
    $result = [PSCustomObject]@{
        LatestVersion = $latestVersion
        DotnetCommandWorkloadSetVersion = $dotnetCommandWorkloadSetVersion
        LinuxTag = $linuxTag
        WindowsTag = $windowsTag
        HasLinuxBuild = $false
        HasWindowsBuild = $false
        TriggerBuilds = $true
        NewVersion = $true
        ErrorMessage = $_.Exception.Message
        DockerRepository = $DockerRepository
        DotnetVersion = $DotnetVersion
    }
    
    if ($OutputFormat -eq "github-actions") {
        Write-GitHubOutput "trigger-builds" "true"
        Write-GitHubOutput "new-version" "true"
        Write-GitHubOutput "workload-set-version" $latestVersion
        Write-GitHubOutput "dotnet-command-workload-set-version" $dotnetCommandWorkloadSetVersion
        Write-GitHubOutput "linux-tag" $linuxTag
        Write-GitHubOutput "windows-tag" $windowsTag
    } else {
        return $result
    }
    
    exit 1
}

# Function to check for existing test builds with Android API levels
function Test-TestRepositoryBuilds {
    param(
        [string]$Repository,
        [string]$TagPattern,
        [string]$DotnetVersion,
        [string]$WorkloadVersion
    )
    
    Write-HostWithPrefix "Checking test repository: $Repository"
    
    try {
        # Get tags from Docker Hub API for test repository
        $dockerHubUri = "https://registry.hub.docker.com/v2/repositories/$Repository/tags?page_size=100"
        Write-HostWithPrefix "Querying Docker Hub API for test repo: $dockerHubUri"
        
        $tagsResponse = Invoke-RestMethod -Uri $dockerHubUri -TimeoutSec 30
        $existingTags = $tagsResponse.results | ForEach-Object { $_.name }
        
        Write-HostWithPrefix "Found $($existingTags.Count) test repository tags"
        
        # Create test tag patterns for common API levels (we check for any Android API level)
        # The test tag pattern is: appium-emulator-linux-dotnet{version}-workloads{workload}-android{api}
        $testPlatform = "appium-emulator-linux"
        $testTagPattern = $TagPattern -replace '\{platform\}', $testPlatform -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $WorkloadVersion
        
        # Check if any tag matches the pattern with any API level
        $matchingTags = $existingTags | Where-Object { 
            $_ -match "^$($testTagPattern -replace '\{api_level\}', '\d+')" 
        }
        
        $hasTestBuilds = $matchingTags.Count -gt 0
        
        Write-HostWithPrefix "Test tag pattern (with API level): $($testTagPattern -replace '\{api_level\}', 'XX')"
        Write-HostWithPrefix "Matching test tags found: $($matchingTags.Count)"
        if ($matchingTags.Count -gt 0 -and $matchingTags.Count -le 5) {
            Write-HostWithPrefix "Sample matching tags: $($matchingTags -join ', ')"
        } elseif ($matchingTags.Count -gt 5) {
            Write-HostWithPrefix "Sample matching tags: $($matchingTags[0..4] -join ', ')..."
        }
        
        return $hasTestBuilds
        
    } catch {
        Write-HostWithPrefix "Warning: Could not check test repository $Repository - $($_.Exception.Message)"
        return $false
    }
}
