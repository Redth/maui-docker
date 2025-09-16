function Get-PlatformPaths {
    param()

    $platform = Get-Platform
    $userHome = [System.Environment]::GetFolderPath("UserProfile")

    switch ($platform) {
        "Windows" {
            return @{
                DotnetDefaultDir = Join-Path $userHome ".dotnet"
                AndroidDefaultHome = Join-Path $userHome "AppData\Local\Android\Sdk"
                LogDefaultDir = Join-Path $userHome "AppData\Local\maui-provisioning\logs"
                DotnetToolsDir = Join-Path $userHome ".dotnet\tools"
                PackageManager = "choco"  # Could also support winget
                PackageManagerInstallCmd = @("install", "-y")
            }
        }
        "macOS" {
            return @{
                DotnetDefaultDir = Join-Path $userHome ".dotnet"
                AndroidDefaultHome = Join-Path $userHome "Library/Android/sdk"
                LogDefaultDir = Join-Path $userHome "Library/Logs/maui-provisioning"
                DotnetToolsDir = Join-Path $userHome ".dotnet/tools"
                PackageManager = "brew"
                PackageManagerInstallCmd = @("install")
            }
        }
        "Linux" {
            return @{
                DotnetDefaultDir = Join-Path $userHome ".dotnet"
                AndroidDefaultHome = Join-Path $userHome "Android/Sdk"
                LogDefaultDir = Join-Path $userHome ".local/share/maui-provisioning/logs"
                DotnetToolsDir = Join-Path $userHome ".dotnet/tools"
                PackageManager = "apt"  # Could detect package manager
                PackageManagerInstallCmd = @("install", "-y")
            }
        }
        default {
            throw "Unsupported platform: $platform"
        }
    }
}