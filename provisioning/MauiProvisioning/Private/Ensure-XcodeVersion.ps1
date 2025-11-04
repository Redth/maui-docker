function Ensure-XcodeVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RecommendedVersion,
        [string]$VersionRange
    )

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun

    # Get currently installed Xcode versions
    $installedVersions = Get-InstalledXcodeVersions

    # Check if recommended version is already installed
    if ($installedVersions.ContainsKey($RecommendedVersion)) {
        $xcodeInfo = $installedVersions[$RecommendedVersion]
        Write-Host "Xcode $RecommendedVersion already installed at $($xcodeInfo.Path)"

        # Check if it's selected
        if (-not $xcodeInfo.IsSelected) {
            if ($isDryRun) {
                Write-Host "[DryRun] Would select Xcode $RecommendedVersion using xcodes"
            } else {
                Write-Host "Selecting Xcode $RecommendedVersion..."
                try {
                    Invoke-ExternalCommand -Command "xcodes" -Arguments @("select", "--path", $xcodeInfo.Path)
                    Write-Host "Successfully selected Xcode $RecommendedVersion"
                } catch {
                    Write-Warning "Failed to select Xcode $RecommendedVersion`: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host "Xcode $RecommendedVersion is already selected"
        }

        # Install command line tools for the selected Xcode
        if ($isDryRun) {
            Write-Host "[DryRun] Would install Xcode command line tools"
        } else {
            try {
                Write-Host "Installing Xcode command line tools..."
                # This will prompt if needed, or do nothing if already installed
                Invoke-ExternalCommand -Command "xcode-select" -Arguments @("--install") -IgnoreExitCode
            } catch {
                Write-Warning "Command line tools installation may have failed: $($_.Exception.Message)"
            }
        }

        return $true
    }

    # Check if any compatible version is installed
    $compatibleVersion = $null
    foreach ($version in $installedVersions.Keys) {
        # Simple version comparison - could be enhanced
        if ([Version]::TryParse($version, [ref]$null) -and [Version]::TryParse($RecommendedVersion, [ref]$null)) {
            if ([Version]$version -ge [Version]$RecommendedVersion) {
                $compatibleVersion = $version
                break
            }
        }
    }

    if ($compatibleVersion) {
        Write-Host "Found compatible Xcode version $compatibleVersion (recommended: $RecommendedVersion)"
        $xcodeInfo = $installedVersions[$compatibleVersion]

        if (-not $xcodeInfo.IsSelected) {
            if ($isDryRun) {
                Write-Host "[DryRun] Would select Xcode $compatibleVersion using xcodes"
            } else {
                Write-Host "Selecting Xcode $compatibleVersion..."
                try {
                    Invoke-ExternalCommand -Command "xcodes" -Arguments @("select", "--path", $xcodeInfo.Path)
                    Write-Host "Successfully selected Xcode $compatibleVersion"
                } catch {
                    Write-Warning "Failed to select Xcode $compatibleVersion`: $($_.Exception.Message)"
                }
            }
        }
        return $true
    }

    # Need to install the recommended version
    if (-not (Ensure-XcodesApp)) {
        Write-Warning "Cannot install Xcode without xcodes app"
        return $false
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install Xcode $RecommendedVersion using xcodes"
        Write-Host "[DryRun] Would select Xcode $RecommendedVersion using xcodes"
        Write-Host "[DryRun] Would install Xcode command line tools"
        return $true
    }

    try {
        Write-Host "Installing Xcode $RecommendedVersion... (this may take a while)"

        # Install the specific version
        Invoke-ExternalCommand -Command "xcodes" -Arguments @("install", $RecommendedVersion, "--experimental-unxip")

        # Select the newly installed version
        $newXcodePath = "/Applications/Xcode-$RecommendedVersion.app"
        if (-not (Test-Path $newXcodePath)) {
            $newXcodePath = "/Applications/Xcode.app"
        }

        Write-Host "Selecting Xcode $RecommendedVersion..."
        Invoke-ExternalCommand -Command "xcodes" -Arguments @("select", "--path", $newXcodePath)

        # Install command line tools
        Write-Host "Installing Xcode command line tools..."
        Invoke-ExternalCommand -Command "xcode-select" -Arguments @("--install") -IgnoreExitCode

        Write-Host "Successfully installed and configured Xcode $RecommendedVersion"
        return $true

    } catch {
        Write-Warning "Failed to install Xcode $RecommendedVersion`: $($_.Exception.Message)"
        return $false
    }
}
