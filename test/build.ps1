Param(
    [String]$DockerRepository="redth/maui-testing",
    [String]$DockerPlatform="linux/amd64",
    [String]$AndroidSdkApiLevel=35,
    [String]$Version="latest",
    [String]$WorkloadSetVersion="",
    [String]$DotnetVersion="9.0",
    [String]$AppiumVersion="",
    [String]$AppiumUIAutomator2DriverVersion="",
    [Bool]$Load=$false,
    [Bool]$Push=$false) 

if ($DockerPlatform.StartsWith('linux/')) {
    $dockerTagBase = "appium-emulator-linux"
} else {
    # Error not supported platform
    Write-Error "Unsupported Docker platform: $DockerPlatform"
    exit 1
}

# Import common functions for workload detection
$commonFunctionsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\common-functions.ps1" -Resolve -ErrorAction SilentlyContinue

if ($commonFunctionsPath -and (Test-Path -Path $commonFunctionsPath -PathType Leaf)) {
    . $commonFunctionsPath
    Write-Host "Imported common functions from $commonFunctionsPath"
} else {
    Write-Error "Could not find common functions file at expected path: ..\common-functions.ps1"
    exit 1
}

# Get latest Appium versions if not provided
if ([string]::IsNullOrEmpty($AppiumVersion) -or [string]::IsNullOrEmpty($AppiumUIAutomator2DriverVersion)) {
    Write-Host "Getting latest Appium versions from npm..."
    $latestAppiumVersions = Get-LatestAppiumVersions
    
    if ([string]::IsNullOrEmpty($AppiumVersion)) {
        if ($latestAppiumVersions.AppiumVersion) {
            $AppiumVersion = $latestAppiumVersions.AppiumVersion
            Write-Host "Using latest Appium version: $AppiumVersion"
        } else {
            $AppiumVersion = "2.11.0"  # Fallback version
            Write-Warning "Could not get latest Appium version, using fallback: $AppiumVersion"
        }
    }
    
    if ([string]::IsNullOrEmpty($AppiumUIAutomator2DriverVersion)) {
        if ($latestAppiumVersions.UIAutomator2DriverVersion) {
            $AppiumUIAutomator2DriverVersion = $latestAppiumVersions.UIAutomator2DriverVersion
            Write-Host "Using latest Appium UIAutomator2 driver version: $AppiumUIAutomator2DriverVersion"
        } else {
            $AppiumUIAutomator2DriverVersion = "3.6.0"  # Fallback version
            Write-Warning "Could not get latest Appium UIAutomator2 driver version, using fallback: $AppiumUIAutomator2DriverVersion"
        }
    }
} else {
    Write-Host "Using provided Appium versions:"
    Write-Host "  Appium: $AppiumVersion"
    Write-Host "  UIAutomator2 Driver: $AppiumUIAutomator2DriverVersion"
}

# Get comprehensive workload information with a single call
Write-Host "Getting workload information for Android SDK dependencies..."
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

Write-Host "Android workload details retrieved successfully:"
Write-Host "  API Level: $($androidDetails.ApiLevel)"
Write-Host "  Build Tools Version: $($androidDetails.BuildToolsVersion)"
Write-Host "  Command Line Tools Version: $($androidDetails.CmdLineToolsVersion)"
Write-Host "  JDK Major Version: $($androidDetails.JdkMajorVersion)"
Write-Host "  System Image Type: $($androidDetails.SystemImageType)"
Write-Host "  AVD Device Type: $($androidDetails.AvdDeviceType)"

# Use workload-detected values for Android SDK components
$androidBuildToolsVersion = $androidDetails.BuildToolsVersion
$androidCmdLineToolsVersion = $androidDetails.CmdLineToolsVersion
$androidJdkMajorVersion = $androidDetails.JdkMajorVersion
$androidAvdSystemImageType = $androidDetails.SystemImageType
$androidAvdDeviceType = $androidDetails.AvdDeviceType

# Extract the dotnet command version for Docker tags
$dotnetCommandWorkloadSetVersion = $workloadInfo.DotnetCommandWorkloadSetVersion

# Determine which Android SDK API level to use
# Use the parameter provided, which could be from the matrix or a specific override
Write-Host "Using Android SDK API Level: $AndroidSdkApiLevel (from parameter/matrix)"
Write-Host "Workload default API Level: $($androidDetails.ApiLevel) (will be available in the built image)"

Write-Host "Docker tags that will be created:"
Write-Host "  ${DockerRepository}:${dockerTagBase}-android${AndroidSdkApiLevel}-v${Version}"
Write-Host "  ${DockerRepository}:${dockerTagBase}-android${AndroidSdkApiLevel}"
Write-Host "  ${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-android${AndroidSdkApiLevel}"
Write-Host "  ${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-android${AndroidSdkApiLevel}-v${Version}"
Write-Host "  ${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-workloads${dotnetCommandWorkloadSetVersion}-android${AndroidSdkApiLevel}"
Write-Host "  ${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-workloads${dotnetCommandWorkloadSetVersion}-android${AndroidSdkApiLevel}-v${Version}"

# Define all buildx arguments in an array to avoid backtick issues
$buildxArgs = @(
    "buildx", "build",
    "--platform", "linux/amd64", #"--platform", "linux/amd64,linux/arm64",
    "-f", "Dockerfile",
    "--build-arg", "ANDROID_SDK_API_LEVEL=$AndroidSdkApiLevel",
    "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$androidBuildToolsVersion",
    "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$androidCmdLineToolsVersion",
    "--build-arg", "ANDROID_SDK_AVD_DEVICE_TYPE=$androidAvdDeviceType",
    "--build-arg", "ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE=$androidAvdSystemImageType",
    "--build-arg", "APPIUM_VERSION=$AppiumVersion",
    "--build-arg", "APPIUM_UIAUTOMATOR2_DRIVER_VERSION=$AppiumUIAutomator2DriverVersion",
    "--build-arg", "JAVA_JDK_MAJOR_VERSION=$androidJdkMajorVersion",
    # Original tags
    "-t", "${DockerRepository}:${dockerTagBase}-android${AndroidSdkApiLevel}-v${Version}",
    "-t", "${DockerRepository}:${dockerTagBase}-android${AndroidSdkApiLevel}",
    # New tags with .NET version
    "-t", "${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-android${AndroidSdkApiLevel}",
    "-t", "${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-android${AndroidSdkApiLevel}-v${Version}",
    # New tags with .NET version and workload set version
    "-t", "${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-workloads${dotnetCommandWorkloadSetVersion}-android${AndroidSdkApiLevel}",
    "-t", "${DockerRepository}:${dockerTagBase}-dotnet${DotnetVersion}-workloads${dotnetCommandWorkloadSetVersion}-android${AndroidSdkApiLevel}-v${Version}"
)

# Add load flag if specified (only supported by buildx, and test images are Linux-only)
if ($Load) {
    Write-Host "Adding --load flag for Linux build"
    $buildxArgs += "--load"
}

$buildxArgs += "."

# Change to the test directory to ensure correct build context
Push-Location $PSScriptRoot

try {
    # Execute the docker command with all arguments
    & docker $buildxArgs

    # Output information for debugging
    Write-Host "Docker buildx command completed with exit code: $LASTEXITCODE"
} finally {
    # Always return to original directory
    Pop-Location
}



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
