function Get-InstalledIosSimulatorRuntimes {
    param()

    $installed = @{}

    if (Test-DryRun) {
        return $installed
    }

    try {
        $jsonOutput = & xcrun simctl list runtimes --json 2>$null
        if ($LASTEXITCODE -eq 0 -and $jsonOutput) {
            $parsed = $jsonOutput | ConvertFrom-Json -ErrorAction Stop
            if ($parsed.runtimes) {
                foreach ($runtime in $parsed.runtimes) {
                    $name = $runtime.name
                    if (-not $name) { continue }
                    if ($name -notmatch '^iOS ') { continue }

                    $version = $runtime.version
                    if (-not $version -and $name -match '^iOS\s+([0-9\.]+)') {
                        $version = $Matches[1]
                    }

                    if ($version) {
                        $installed[$version] = $runtime
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to enumerate installed iOS simulator runtimes: $($_.Exception.Message)"
    }

    return $installed
}
