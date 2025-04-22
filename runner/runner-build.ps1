Param([String]$DotnetVersion="9.0",
    [String]$WorkloadSetVersion="",
    [String]$DockerRepository="redth/maui-docker",
    [String]$DockerPlatform="windows/amd64",
    [String]$Version="latest",
    [Bool]$Load=$false,
    [Bool]$Push=$false)

if ($DockerPlatform.StartsWith('linux/')) {
    $dockerImageName = "build-linux"
} else {
    $dockerImageName = "build-windows"
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
        "--build-arg", "ANDROID_SDK_API_LEVEL=$androidApiLevel",
        "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$androidBuildToolsVersion",
        "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$androidCmdLineToolsVersion",
        "--build-arg", "JDK_MAJOR_VERSION=$androidJdkMajorVersion",
        "--build-arg", "DOTNET_WORKLOADS_VERSION=$dotnetCommandWorkloadSetVersion",
        "-t", "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion",
        "-t", "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion",
        "-t", "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$Version"
        
        if ($Load) {
            $buildxArgs += "--load"
        }
    )
} else {
    $buildxArgs = @(
        "build",
        "--build-arg", "ANDROID_SDK_API_LEVEL=$androidApiLevel",
        "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$androidBuildToolsVersion",
        "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$androidCmdLineToolsVersion",
        "--build-arg", "JDK_MAJOR_VERSION=$androidJdkMajorVersion",
        "--build-arg", "DOTNET_WORKLOADS_VERSION=$dotnetCommandWorkloadSetVersion",
        "-t", "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion",
        "-t", "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion",
        "-t", "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$Version"
    )
}


if ($DockerPlatform.StartsWith('linux/')) {
    $buildxArgs += "-f"
    $buildxArgs += "$PSScriptRoot\\linux\\Dockerfile"
} else {
    $buildxArgs += "-f"
    $buildxArgs += "$PSScriptRoot\\windows\\Dockerfile"
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
        "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion",
        "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion",
        "${DockerRepository}/${dockerImageName}:dotnet$DotnetVersion-workloads$dotnetCommandWorkloadSetVersion-v$Version"
    )

    & docker $pushArgs
    Write-Host "Docker push command completed with exit code: $LASTEXITCODE"
}