function Get-InstalledXcodeVersions {
    param()

    $installedVersions = @{}

    try {
        # Check if xcodes app is available
        if (Get-Command xcodes -ErrorAction SilentlyContinue) {
            $output = & xcodes installed 2>$null
            if ($LASTEXITCODE -eq 0 -and $output) {
                foreach ($line in $output) {
                    # Parse lines like "16.4 (16L65) ✓ (/Applications/Xcode.app)"
                    if ($line -match '^(\d+\.?\d*(?:\.\d+)?)\s+\([^)]+\)\s+(.*)$') {
                        $version = $Matches[1]
                        $status = $Matches[2].Trim()
                        $isSelected = $status -match '✓'
                        $path = if ($status -match '\(([^)]+)\)') { $Matches[1] } else { $null }

                        $installedVersions[$version] = @{
                            Version = $version
                            IsSelected = $isSelected
                            Path = $path
                        }
                    }
                }
            }
        } else {
            # Fallback: check common Xcode installation paths
            $commonPaths = @(
                "/Applications/Xcode.app",
                "/Applications/Xcode-beta.app"
            )

            foreach ($path in $commonPaths) {
                if (Test-Path $path) {
                    try {
                        $plistPath = Join-Path $path "Contents/version.plist"
                        if (Test-Path $plistPath) {
                            $versionOutput = & plutil -p $plistPath 2>$null
                            if ($LASTEXITCODE -eq 0 -and $versionOutput) {
                                # Parse version from plist output
                                if ($versionOutput -match '"CFBundleShortVersionString"\s*=>\s*"([^"]+)"') {
                                    $version = $Matches[1]
                                    $isSelected = & xcode-select -p 2>$null | Out-String | Where-Object { $_ -like "*$path*" }

                                    $installedVersions[$version] = @{
                                        Version = $version
                                        IsSelected = [bool]$isSelected
                                        Path = $path
                                    }
                                }
                            }
                        }
                    } catch {
                        Write-Warning "Failed to read Xcode version from $path`: $($_.Exception.Message)"
                    }
                }
            }
        }
    } catch {
        Write-Warning "Failed to detect Xcode installations: $($_.Exception.Message)"
    }

    return $installedVersions
}