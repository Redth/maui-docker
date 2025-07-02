Param([String]$DotnetVersion="9.0",
    [String]$WorkloadSetVersion="",
    [String]$DockerRepository="redth/maui-docker-base",
    [String]$DockerPlatform="windows/amd64",
    [String]$Version="latest",
    [Bool]$Load=$false,
    [Bool]$Push=$false)

if ($DockerPlatform.StartsWith('linux/')) {
    $dockerTagBase = "linux"
} else {
    $dockerTagBase = "windows"
}

# Use a more reliable method to import the common functions module
# This handles paths with spaces better and is more explicit
$commonFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\common-functions.ps1" -Resolve -ErrorAction SilentlyContinue

if ($commonFunctionsPath -and (Test-Path -Path $commonFunctionsPath -PathType Leaf)) {
    # Import as a module using the source command for better scoping
    . $commonFunctionsPath
    Write-Host "Imported common functions from $commonFunctionsPath"
} else {
    Write-Error "Could not find common functions file at expected path: ..\common-functions.ps1"
    exit 1
}

# Get comprehensive workload information with a single call
$workloadInfo = Get-WorkloadInfo -DotnetVersion $DotnetVersion -WorkloadSetVersion $WorkloadSetVersion -IncludeAndroid -DockerPlatform $DockerPlatform

if (-not $workloadInfo) {
    Write-Error "Failed to get workload information."
    exit 1
}

# Extract Android-specific information
$androidWorkload = $workloadInfo.Workloads["Microsoft.NET.Sdk.Android"]
if (-not $androidWorkload) {
    Write-Error "Could not find Android workload in the workload set."
    exit 1
}

# Extract Android details if available
$androidDetails = $androidWorkload.Details
if (-not $androidDetails) {
    Write-Error "Could not extract Android details from workload."
    exit 1
}

# Extract the dotnet command version for Docker tags
$dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion

Write-Host "Building MAUI Base Image for $DockerPlatform"
Write-Host "=============================================="
Write-Host ".NET Version: $DotnetVersion"
Write-Host "Workload Set Version: $($workloadInfo.ResolvedWorkloadSetVersion)"
Write-Host "Dotnet Command Workload Set Version: $dotnetCommandWorkloadSetVersion"
Write-Host "Android SDK API Level: $($androidDetails.AndroidSdkApiLevel)"
Write-Host "Android SDK Build Tools Version: $($androidDetails.AndroidSdkBuildToolsVersion)"
Write-Host "Android SDK Command Line Tools Version: $($androidDetails.AndroidSdkCommandLineToolsVersion)"
Write-Host "JDK Major Version: $($androidDetails.JdkMajorVersion)"
Write-Host "Docker Repository: $DockerRepository"
Write-Host "Docker Platform: $DockerPlatform"
Write-Host "Version: $Version"

# Determine the build context path based on the platform
$contextPath = Join-Path -Path $PSScriptRoot -ChildPath $dockerTagBase

if (-not (Test-Path -Path $contextPath -PathType Container)) {
    Write-Error "Build context path does not exist: $contextPath"
    exit 1
}

Write-Host "Using build context: $contextPath"

# Build multiple tags for consistency with runner images
$primaryTag = "$DockerRepository`:$dockerTagBase-$Version"
$dotnetTag = "$DockerRepository`:$dockerTagBase-dotnet$DotnetVersion"
$workloadTag = "$DockerRepository`:$dockerTagBase-dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion"
$versionedTag = "$DockerRepository`:$dockerTagBase-dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$Version"

Write-Host "Building Docker image with tags:"
Write-Host "  Primary: $primaryTag"
Write-Host "  .NET: $dotnetTag"
Write-Host "  Workloads: $workloadTag"
Write-Host "  Versioned: $versionedTag"

# Prepare Docker build arguments
$buildArgs = @(
    "--build-arg", "DOTNET_VERSION=$DotnetVersion",
    "--build-arg", "JDK_MAJOR_VERSION=$($androidDetails.JdkMajorVersion)",
    "--build-arg", "ANDROID_SDK_API_LEVEL=$($androidDetails.AndroidSdkApiLevel)", 
    "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$($androidDetails.AndroidSdkBuildToolsVersion)",
    "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$($androidDetails.AndroidSdkCommandLineToolsVersion)",
    "--build-arg", "DOTNET_WORKLOADS_VERSION=$dotnetCommandWorkloadSetVersion",
    "--platform", $DockerPlatform,
    "--tag", $primaryTag,
    "--tag", $dotnetTag,
    "--tag", $workloadTag,
    "--tag", $versionedTag
)

# Add load flag if specified
if ($Load) {
    $buildArgs += @("--load")
}

# Change to the build context directory
Push-Location $contextPath

try {
    # Execute the Docker build command
    Write-Host "Executing: docker build $($buildArgs -join ' ') ."
    & docker build @buildArgs .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    
    Write-Host "Docker build completed successfully!"
    
    # Push if requested
    if ($Push) {
        $tagsToPush = @($primaryTag, $dotnetTag, $workloadTag, $versionedTag)
        
        foreach ($tag in $tagsToPush) {
            Write-Host "Pushing image: $tag"
            & docker push $tag
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Docker push failed for $tag with exit code $LASTEXITCODE"
                exit $LASTEXITCODE
            }
        }
        
        Write-Host "Docker push completed successfully!"
    }
    
} finally {
    # Return to the original directory
    Pop-Location
}
