Param([String]$DotnetVersion="9.0",
    [String]$WorkloadSetVersion="",
    [String]$DockerRepository="redth/maui-actions-runner",
    [String]$BaseDockerRepository="redth/maui-build",
    [String]$DockerPlatform="windows/amd64",
    [String]$Version="latest",
    [Bool]$Load=$false,
    [Bool]$Push=$false,
    [Bool]$BuildBase=$false)

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

Write-Host "Building MAUI Actions Runner Image"
Write-Host "=================================="
Write-Host ".NET Version: $DotnetVersion"
Write-Host "Workload Set Version: $($workloadInfo.ResolvedWorkloadSetVersion)"
Write-Host "Dotnet Command Workload Set Version: $dotnetCommandWorkloadSetVersion"
Write-Host "Base Image Tag: $dotnetCommandWorkloadSetVersion"
Write-Host "Docker Repository: $DockerRepository"
Write-Host "Docker Platform: $DockerPlatform"
Write-Host ""
Write-Host "NOTE: This build assumes the base image '$BaseDockerRepository`:$dockerTagBase-$dotnetCommandWorkloadSetVersion' exists."
Write-Host "If it doesn't exist, build it first with: ../base/base-build.ps1 -DotnetVersion $DotnetVersion -DockerPlatform $DockerPlatform"
Write-Host ""

# Build base image if requested
if ($BuildBase) {
    Write-Host "Building base image first..."
    $baseBuildScript = Join-Path -Path $PSScriptRoot -ChildPath "..\base\base-build.ps1"
    if (Test-Path $baseBuildScript) {
        & $baseBuildScript -DotnetVersion $DotnetVersion -DockerRepository $BaseDockerRepository -DockerPlatform $DockerPlatform -Version $dotnetCommandWorkloadSetVersion -Load:$Load
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Base image build failed with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
        Write-Host "Base image build completed successfully!"
        Write-Host ""
    } else {
        Write-Error "Could not find base build script at: $baseBuildScript"
        exit 1
    }
}

# Use provided values or get them from the workload info
if (-not $androidApiLevel) {
    $androidApiLevel = $androidDetails.ApiLevel
    Write-Host "Using API Level from workload: $androidApiLevel"
}

if (-not $androidBuildToolsVersion) {
    $androidBuildToolsVersion = $androidDetails.BuildToolsVersion
    Write-Host "Using Build Tools version from workload: $androidBuildToolsVersion"
}

if (-not $androidCmdLineToolsVersion) {
    $androidCmdLineToolsVersion = $androidDetails.CmdLineToolsVersion
    Write-Host "Using Command Line Tools version from workload: $androidCmdLineToolsVersion"
}

if (-not $androidJdkMajorVersion) {
    $androidJdkMajorVersion = $androidDetails.JdkMajorVersion
    Write-Host "Using JDK Major version from workload: $androidJdkMajorVersion"
}


# Define all buildx arguments in an array to avoid backtick issues
if ($DockerPlatform.StartsWith('linux/')) {
    $buildxArgs = @(
        "buildx", "build",
        "--platform", $DockerPlatform,
        "--build-arg", "BASE_IMAGE_TAG=$dotnetCommandWorkloadSetVersion",
        "--build-arg", "BASE_DOCKER_REPOSITORY=$BaseDockerRepository",
        "--build-arg", "GITHUB_ACTIONS_RUNNER_VERSION=2.323.0",
        "-t", "${DockerRepository}:${dockerTagBase}-dotnet$DotnetVersion",
        "-t", "${DockerRepository}:${dockerTagBase}-dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion",
        "-t", "${DockerRepository}:${dockerTagBase}-dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$Version"
        
        if ($Load) {
            $buildxArgs += "--load"
        }
    )
} else {
    $buildxArgs = @(
        "build",
        "--build-arg", "BASE_IMAGE_TAG=$dotnetCommandWorkloadSetVersion",
        "--build-arg", "BASE_DOCKER_REPOSITORY=$BaseDockerRepository",
        "--build-arg", "GITHUB_ACTIONS_RUNNER_VERSION=2.323.0",
        "-t", "${DockerRepository}:${dockerTagBase}-dotnet$DotnetVersion",
        "-t", "${DockerRepository}:${dockerTagBase}-dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion",
        "-t", "${DockerRepository}:${dockerTagBase}-dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$Version"
    )
}


if ($DockerPlatform.StartsWith('linux/')) {
    $buildxArgs += "-f"
    $buildxArgs += "$PSScriptRoot/linux/Dockerfile"
} else {
    $buildxArgs += "-f"
    $buildxArgs += "$PSScriptRoot/windows/Dockerfile"
}

$buildxArgs += "."

# Execute the docker command with all arguments
& docker $buildxArgs

# Output information for debugging
Write-Host "Docker buildx command completed with exit code: $LASTEXITCODE"


if ($Push) {
    # Push the image to the Docker repository
    $pushArgs = @(
        "push",
        "--all-tags",
        "${DockerRepository}"
    )

    & docker $pushArgs
    Write-Host "Docker push command completed with exit code: $LASTEXITCODE"
}