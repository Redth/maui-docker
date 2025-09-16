function Get-InstalledDotnetWorkloads {
    param([string]$DotnetPath)

    $installed = @{}

    try {
        $jsonOutput = & $DotnetPath workload list --machine-readable 2>$null
        if ($LASTEXITCODE -eq 0 -and $jsonOutput) {
            $parsed = $jsonOutput | ConvertFrom-Json -ErrorAction Stop
            $collections = @()
            if ($parsed.workloads) { $collections += $parsed.workloads }
            if ($parsed.installed) { $collections += $parsed.installed }
            foreach ($entry in $collections) {
                $id = $entry.id
                if (-not $id) { $id = $entry.workloadId }
                if (-not $id -and $entry -is [string]) { $id = $entry }
                if ($id) {
                    $installed[$id] = $entry
                }
            }
            return $installed
        }
    } catch {
        Write-Warning "Failed to read machine-readable workload list: $($_.Exception.Message)"
    }

    try {
        $textOutput = & $DotnetPath workload list 2>$null
        if ($LASTEXITCODE -eq 0 -and $textOutput) {
            foreach ($line in $textOutput) {
                if ($line -match '^\s*([\w\-\.]+)\s*$' -and $line -notmatch ':') {
                    $installed[$Matches[1]] = @{ }
                }
            }
        }
    } catch {
        Write-Warning "Failed to read workload list: $($_.Exception.Message)"
    }

    return $installed
}
