Param([String]$AndroidSdkApiLevel=35,
      [String]$Version="latest",
      [String]$MauiVersionPropsCommit="b2b2191462463e5239184b0a47ec0d0fe2d07e7d") 

# Variables
$MauiVersionPropsUrl = "https://raw.githubusercontent.com/dotnet/maui/$MauiVersionPropsCommit/eng/Versions.props"

# Download file
Invoke-WebRequest -Uri $MauiVersionPropsUrl -OutFile './mauiversion.props'

# Parse XML document
[xml]$xmlDoc = Get-Content -Path './mauiversion.props'

$output = @()

# Select nodes containing 'Appium', 'Android', or 'Java' in PropertyGroup
$nodes = $xmlDoc.SelectNodes("//Project/PropertyGroup/*[contains(name(),'Appium') or contains(name(),'Android') or contains(name(),'Java')]")

foreach ($node in $nodes) {
    if ($node.Name.StartsWith("Appium") -or $node.Name.StartsWith("Android") -or $node.Name.StartsWith("Java")) {
        Set-Item "env:MAUI_$($node.Name)" $node.InnerText
    }
}

# Select specific AndroidSdkApiLevels attribute
$androidSdkNode = $xmlDoc.SelectSingleNode("//Project/ItemGroup/AndroidSdkApiLevels[@Include='$AndroidSdkApiLevel']")

if ($androidSdkNode -and $androidSdkNode.SystemImageType) {
    Set-Item "env:MAUI_AndroidAvdSystemImageType" $($androidSdkNode.SystemImageType)
}

Remove-Item -Path './mauiversion.props'

# Define all buildx arguments in an array to avoid backtick issues
$buildxArgs = @(
    "buildx", "build",
    "--platform", "linux/amd64", #"--platform", "linux/amd64,linux/arm64",
    "--build-arg", "ANDROID_SDK_API_LEVEL=$AndroidSdkApiLevel",
    "--build-arg", "ANDROID_SDK_BUILD_TOOLS_VERSION=$env:MAUI_AndroidSdkBuildToolsVersion",
    "--build-arg", "ANDROID_SDK_CMDLINE_TOOLS_VERSION=$env:MAUI_AndroidSdkCmdLineToolsVersion",
    "--build-arg", "ANDROID_SDK_AVD_DEVICE_TYPE=$env:MAUI_AndroidSdkAvdDeviceType",
    "--build-arg", "ANDROID_SDK_AVD_SYSTEM_IMAGE_TYPE=$env:MAUI_AndroidAvdSystemImageType",
    "--build-arg", "APPIUM_VERSION=$env:MAUI_AppiumVersion",
    "--build-arg", "APPIUM_UIAUTOMATOR2_DRIVER_VERSION=$env:MAUI_AppiumUIAutomator2DriverVersion",
    "--build-arg", "JAVA_JDK_MAJOR_VERSION=$($env:MAUI_JavaJdkVersion.Split('.')[0])",
    "-t", "maui-android-appium:emulator_${AndroidSdkApiLevel}_${Version}",
    "-t", "maui-android-appium:emulator_${AndroidSdkApiLevel}",
    "."
)

# Execute the docker command with all arguments
& docker $buildxArgs

# Output information for debugging
Write-Host "Docker buildx command completed with exit code: $LASTEXITCODE"