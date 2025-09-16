function Ensure-PackageManager {
    param()

    $platform = Get-Platform
    $platformPaths = Get-PlatformPaths

    switch ($platform) {
        "macOS" {
            if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
                throw "Homebrew is required but was not found. Install Homebrew from https://brew.sh and rerun the script."
            }
            return $true
        }
        "Windows" {
            # Check for Chocolatey first, then winget
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                return $true
            } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
                # Update platform paths to use winget
                $platformPaths.PackageManager = "winget"
                $platformPaths.PackageManagerInstallCmd = @("install")
                return $true
            } else {
                Write-Warning "Neither Chocolatey nor winget found. Please install Chocolatey (https://chocolatey.org) or ensure winget is available."
                return $false
            }
        }
        "Linux" {
            # Check for common package managers
            if (Get-Command apt -ErrorAction SilentlyContinue) {
                return $true
            } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
                $platformPaths.PackageManager = "dnf"
                $platformPaths.PackageManagerInstallCmd = @("install", "-y")
                return $true
            } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                $platformPaths.PackageManager = "yum"
                $platformPaths.PackageManagerInstallCmd = @("install", "-y")
                return $true
            } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
                $platformPaths.PackageManager = "pacman"
                $platformPaths.PackageManagerInstallCmd = @("-S", "--noconfirm")
                return $true
            } else {
                Write-Warning "No supported package manager found (apt, dnf, yum, pacman)."
                return $false
            }
        }
        default {
            Write-Warning "Package manager support not implemented for platform: $platform"
            return $false
        }
    }
}

function Update-PackageManager {
    param()

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun
    $platform = Get-Platform
    $platformPaths = Get-PlatformPaths

    if ($isDryRun) {
        Write-Host "[DryRun] Would update package manager ($($platformPaths.PackageManager))"
        return
    }

    switch ($platform) {
        "macOS" {
            Invoke-ExternalCommand -Command "brew" -Arguments @("update")
        }
        "Windows" {
            if ($platformPaths.PackageManager -eq "choco") {
                Invoke-ExternalCommand -Command "choco" -Arguments @("upgrade", "chocolatey")
            }
            # winget updates automatically
        }
        "Linux" {
            switch ($platformPaths.PackageManager) {
                "apt" {
                    Invoke-ExternalCommand -Command "sudo" -Arguments @("apt", "update")
                }
                "dnf" {
                    Invoke-ExternalCommand -Command "sudo" -Arguments @("dnf", "check-update") -IgnoreExitCode
                }
                "yum" {
                    Invoke-ExternalCommand -Command "sudo" -Arguments @("yum", "check-update") -IgnoreExitCode
                }
                "pacman" {
                    Invoke-ExternalCommand -Command "sudo" -Arguments @("pacman", "-Sy")
                }
            }
        }
    }
}