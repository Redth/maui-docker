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

.PARAMETER BaseDockerRepository
    The base Docker repository to check for existing tags. Defaults to "redth/maui-build".

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

.PARAMETER ForceBuild
    Force building and pushing of all images regardless of existing tags with the latest workload set versions.
    When true, the script will always trigger builds even if the tags already exist.

.EXAMPLE
    .\check-workload-updates.ps1
    
.EXAMPLE
    .\check-workload-updates.ps1 -DotnetVersion "9.0" -DockerRepository "myrepo/myimage" -OutputFormat "object"

.EXAMPLE
    .\check-workload-updates.ps1 -ForceBuild -DotnetVersion "9.0"
#>

param(
    [Parameter(Position = 0)]
    [string]$DotnetVersion = "9.0",
    
    [Parameter(Position = 1)]
    [string]$DockerRepository = "redth/maui-actions-runner",
    
    [Parameter(Position = 2)]
    [string]$TestDockerRepository = "redth/maui-testing",
    
    [Parameter(Position = 3)]
    [string]$BaseDockerRepository = "redth/maui-build",
    
    [Parameter(Position = 4)]
    [string]$TagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}",
    
    [Parameter(Position = 5)]
    [string]$TestTagPattern = "{platform}-dotnet{dotnet_version}-workloads{workload_version}-android{api_level}",
    
    [Parameter(Position = 6)]
    [ValidateSet("github-actions", "object")]
    [string]$OutputFormat = "github-actions",
    
    [Parameter()]
    [switch]$ForceBuild
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

# Function to check for existing base builds
function Test-BaseRepositoryBuilds {
    param(
        [string]$Repository,
        [string]$TagPattern,
        [string]$DotnetVersion,
        [string]$WorkloadVersion
    )
    
    Write-HostWithPrefix "Checking base repository: $Repository"
    
    try {
        # Get tags from Docker Hub API for base repository
        $dockerHubUri = "https://registry.hub.docker.com/v2/repositories/$Repository/tags?page_size=100"
        Write-HostWithPrefix "Querying Docker Hub API for base repo: $dockerHubUri"
        
        $tagsResponse = Invoke-RestMethod -Uri $dockerHubUri -TimeoutSec 30
        $existingTags = $tagsResponse.results | ForEach-Object { $_.name }
        
        Write-HostWithPrefix "Found $($existingTags.Count) base repository tags"
        
        # Create base tag patterns for both platforms
        $linuxBaseTag = $TagPattern -replace '\{platform\}', 'linux' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $WorkloadVersion
        $windowsBaseTag = $TagPattern -replace '\{platform\}', 'windows' -replace '\{dotnet_version\}', $DotnetVersion -replace '\{workload_version\}', $WorkloadVersion
        
        $hasLinuxBase = $existingTags -contains $linuxBaseTag
        $hasWindowsBase = $existingTags -contains $windowsBaseTag
        $hasAnyBase = $hasLinuxBase -or $hasWindowsBase
        
        Write-HostWithPrefix "Linux base tag: $linuxBaseTag - Exists: $hasLinuxBase"
        Write-HostWithPrefix "Windows base tag: $windowsBaseTag - Exists: $hasWindowsBase"
        Write-HostWithPrefix "Has any base builds: $hasAnyBase"
        
        return @{
            HasLinuxBase = $hasLinuxBase
            HasWindowsBase = $hasWindowsBase
            HasAnyBase = $hasAnyBase
            LinuxBaseTag = $linuxBaseTag
            WindowsBaseTag = $windowsBaseTag
        }
        
    } catch {
        Write-HostWithPrefix "Warning: Could not check base repository $Repository - $($_.Exception.Message)"
        return @{
            HasLinuxBase = $false
            HasWindowsBase = $false
            HasAnyBase = $false
            LinuxBaseTag = ""
            WindowsBaseTag = ""
        }
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
    $xcodeVersionRange = ""
    $xcodeRecommendedVersion = ""
    $xcodeMajorVersion = ""
    $detailedWorkloadInfo = $null
    
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
        $workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -IncludeAndroid -IncludeiOS -DockerPlatform "linux/amd64"
        
        if (-not $workloadInfo) {
            Write-Error "Failed to get workload information for .NET $DotnetVersion"
            exit 1
        }
        
        Write-HostWithPrefix "Workload info retrieved successfully"
        Write-HostWithPrefix "Available properties: $($workloadInfo.Keys -join ', ')"
        
        $latestVersion = $workloadInfo.WorkloadSetVersion
        $dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion
        $detailedWorkloadInfo = $workloadInfo
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

    # Retrieve iOS workload dependency information for Xcode details
    if (-not $detailedWorkloadInfo) {
        try {
            Write-HostWithPrefix "Retrieving iOS workload dependency information..."
            $detailedWorkloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -WorkloadSetVersion $latestVersion -IncludeiOS -DockerPlatform "linux/amd64"
        } catch {
            Write-HostWithPrefix "Warning: Failed to retrieve iOS workload information - $($_.Exception.Message)"
        }
    }

    if ($detailedWorkloadInfo -and $detailedWorkloadInfo.Workloads -and $detailedWorkloadInfo.Workloads.ContainsKey("Microsoft.NET.Sdk.iOS")) {
        $iosWorkload = $detailedWorkloadInfo.Workloads["Microsoft.NET.Sdk.iOS"]
        if ($iosWorkload -and $iosWorkload.Details) {
            if ($iosWorkload.Details.XcodeVersionRange) {
                $xcodeVersionRange = $iosWorkload.Details.XcodeVersionRange
            }
            if ($iosWorkload.Details.XcodeRecommendedVersion) {
                $xcodeRecommendedVersion = $iosWorkload.Details.XcodeRecommendedVersion
            }
            if ($null -ne $iosWorkload.Details.XcodeMajorVersion) {
                $xcodeMajorVersion = $iosWorkload.Details.XcodeMajorVersion.ToString()
            }

            Write-HostWithPrefix "Xcode version range: $xcodeVersionRange"
            Write-HostWithPrefix "Xcode recommended version: $xcodeRecommendedVersion"
            Write-HostWithPrefix "Xcode major version: $xcodeMajorVersion"
        } else {
            Write-HostWithPrefix "Warning: iOS workload details were not available for Xcode information"
        }
    } else {
        Write-HostWithPrefix "Warning: iOS workload information not found in workload set data"
    }

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
        
        # Check base repository for builds
        $baseBuilds = Test-BaseRepositoryBuilds -Repository $BaseDockerRepository -TagPattern $TagPattern -DotnetVersion $DotnetVersion -WorkloadVersion $dotnetCommandWorkloadSetVersion
        $hasLinuxBaseBuild = $baseBuilds.HasLinuxBase
        $hasWindowsBaseBuild = $baseBuilds.HasWindowsBase
        $hasAnyBaseBuild = $baseBuilds.HasAnyBase
        Write-HostWithPrefix "Has base builds: $hasAnyBaseBuild (Linux: $hasLinuxBaseBuild, Windows: $hasWindowsBaseBuild)"
        
        $hasAnyBuild = $hasLinuxBuild -or $hasWindowsBuild -or $hasTestBuilds -or $hasAnyBaseBuild
        Write-HostWithPrefix "Has any existing build (runner, test, or base): $hasAnyBuild"
        
        # Check if we should force build regardless of existing tags
        if ($ForceBuild) {
            Write-HostWithPrefix "🔄 Force build parameter specified. Builds will be triggered regardless of existing tags."
            $triggerBuilds = $true
            $newVersion = $true
        } elseif (-not $hasAnyBuild) {
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
        
        # Always trigger builds on error or when force build is specified
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
        HasLinuxBaseBuild = $hasLinuxBaseBuild
        HasWindowsBaseBuild = $hasWindowsBaseBuild
        HasAnyBaseBuild = $hasAnyBaseBuild
        TriggerBuilds = $triggerBuilds
        NewVersion = $newVersion
        ForceBuild = $ForceBuild.IsPresent
        XcodeVersionRange = $xcodeVersionRange
        XcodeRecommendedVersion = $xcodeRecommendedVersion
        XcodeMajorVersion = $xcodeMajorVersion
        ErrorMessage = $errorMessage
        DockerRepository = $DockerRepository
        TestDockerRepository = $TestDockerRepository
        BaseDockerRepository = $BaseDockerRepository
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
        Write-GitHubOutput "has-linux-base-build" $hasLinuxBaseBuild.ToString().ToLower()
        Write-GitHubOutput "has-windows-base-build" $hasWindowsBaseBuild.ToString().ToLower()
        Write-GitHubOutput "has-any-base-build" $hasAnyBaseBuild.ToString().ToLower()
        Write-GitHubOutput "force-build" $ForceBuild.IsPresent.ToString().ToLower()
        Write-GitHubOutput "xcode-version-range" $xcodeVersionRange
        Write-GitHubOutput "xcode-recommended-version" $xcodeRecommendedVersion
        Write-GitHubOutput "xcode-major-version" $xcodeMajorVersion
        
        Write-HostWithPrefix "GitHub Actions outputs set:"
        Write-HostWithPrefix "  trigger-builds: $($triggerBuilds.ToString().ToLower())"
        Write-HostWithPrefix "  new-version: $($newVersion.ToString().ToLower())"
        Write-HostWithPrefix "  workload-set-version: $latestVersion"
        Write-HostWithPrefix "  dotnet-command-workload-set-version: $dotnetCommandWorkloadSetVersion"
        Write-HostWithPrefix "  linux-tag: $linuxTag"
        Write-HostWithPrefix "  windows-tag: $windowsTag"
        Write-HostWithPrefix "  has-test-builds: $($hasTestBuilds.ToString().ToLower())"
        Write-HostWithPrefix "  has-linux-base-build: $($hasLinuxBaseBuild.ToString().ToLower())"
        Write-HostWithPrefix "  has-windows-base-build: $($hasWindowsBaseBuild.ToString().ToLower())"
        Write-HostWithPrefix "  has-any-base-build: $($hasAnyBaseBuild.ToString().ToLower())"
        Write-HostWithPrefix "  force-build: $($ForceBuild.IsPresent.ToString().ToLower())"
        Write-HostWithPrefix "  xcode-version-range: $xcodeVersionRange"
        Write-HostWithPrefix "  xcode-recommended-version: $xcodeRecommendedVersion"
        Write-HostWithPrefix "  xcode-major-version: $xcodeMajorVersion"
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
    if (-not $xcodeVersionRange) { $xcodeVersionRange = "" }
    if (-not $xcodeRecommendedVersion) { $xcodeRecommendedVersion = "" }
    if (-not $xcodeMajorVersion) { $xcodeMajorVersion = "" }

    $result = [PSCustomObject]@{
        LatestVersion = $latestVersion
        DotnetCommandWorkloadSetVersion = $dotnetCommandWorkloadSetVersion
        LinuxTag = $linuxTag
        WindowsTag = $windowsTag
        HasLinuxBuild = $false
        HasWindowsBuild = $false
        TriggerBuilds = $true
        NewVersion = $true
        ForceBuild = $ForceBuild.IsPresent
        XcodeVersionRange = $xcodeVersionRange
        XcodeRecommendedVersion = $xcodeRecommendedVersion
        XcodeMajorVersion = $xcodeMajorVersion
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
        Write-GitHubOutput "force-build" $ForceBuild.IsPresent.ToString().ToLower()
        Write-GitHubOutput "xcode-version-range" $xcodeVersionRange
        Write-GitHubOutput "xcode-recommended-version" $xcodeRecommendedVersion
        Write-GitHubOutput "xcode-major-version" $xcodeMajorVersion
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
