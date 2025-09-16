function Get-AndroidInstalledPackages {
    param([string]$AndroidHome)

    $result = @{}

    if (Test-DryRun) {
        return $result
    }

    try {
        $jsonOutput = & "android" sdk list --installed --format json --home $AndroidHome 2>$null
        if ($LASTEXITCODE -eq 0 -and $jsonOutput) {
            try {
                $parsed = $jsonOutput | ConvertFrom-Json -ErrorAction Stop
                $packageNodes = @()
                if ($parsed.packages) {
                    $packageNodes += $parsed.packages
                }
                if ($parsed -is [System.Collections.IEnumerable]) {
                    $packageNodes += $parsed
                }
                foreach ($pkg in $packageNodes) {
                    $id = $pkg.id
                    if (-not $id) { $id = $pkg.packageId }
                    if (-not $id) { $id = $pkg.package }
                    if ($id) {
                        $result[$id] = $pkg
                    }
                }
            } catch {
                foreach ($line in $jsonOutput) {
                    if ($line -match '"id"\s*:\s*"([^"]+)"') {
                        $result[$Matches[1]] = @{}
                    }
                }
            }
        }
    } catch {
        Write-Warning "Failed to list installed Android SDK packages: $($_.Exception.Message)"
    }

    return $result
}
