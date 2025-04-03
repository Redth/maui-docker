# Variables
$env:MAUI_REPO_COMMIT = 'b2b2191462463e5239184b0a47ec0d0fe2d07e7d'
$env:MAUI_VERSION_PROPS_URL = "https://raw.githubusercontent.com/dotnet/maui/$env:MAUI_REPO_COMMIT/eng/Versions.props"

# Create build directory
New-Item -Path './build' -ItemType Directory -Force | Out-Null

# Download file
Invoke-WebRequest -Uri $env:MAUI_VERSION_PROPS_URL -OutFile './build/mauiversion.props'


# Parse XML document
[xml]$xmlDoc = Get-Content -Path './build/mauiversion.props'

$output = @()

# Select nodes containing 'Appium', 'Android', or 'Java' in PropertyGroup
$nodes = $xmlDoc.SelectNodes("//Project/PropertyGroup/*[contains(name(),'Appium') or contains(name(),'Android') or contains(name(),'Java')]")

foreach ($node in $nodes) {
    $output += "`$env:MAUI_$($node.Name) = `"$($node.InnerText)`""
}

# Select specific AndroidSdkApiLevels attribute
$androidSdkNode = $xmlDoc.SelectSingleNode("//Project/ItemGroup/AndroidSdkApiLevels[@Include='${env:ANDROID_SDK_API_LEVEL}']")

if ($androidSdkNode -and $androidSdkNode.SystemImageType) {
    $output += "`$env:MAUI_AndroidAvdSystemImageType = `"$($androidSdkNode.SystemImageType)`""
}

# Write to output file
$output | Out-File -FilePath './build/maui_versions.env' -Encoding UTF8 -Append
