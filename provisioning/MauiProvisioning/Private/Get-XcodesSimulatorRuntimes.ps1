function Get-XcodesSimulatorRuntimes {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('iOS', 'tvOS')]
        [string]$Platform
    )

    $results = @{}

    $xcodesPath = Resolve-XcodesCliPath
    if (-not $xcodesPath) {
        return $results
    }

    try {
        $output = & $xcodesPath runtimes 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $output) {
            return $results
        }

        foreach ($line in $output) {
            $text = $line.Trim()
            if (-not $text) { continue }

            $text = $text -replace '^[\-\*•]\s*', ''

            if ($text -notmatch "^$Platform\s+") {
                continue
            }

            $parenMatches = [regex]::Matches($text, '\([^)]+\)')
            $isInstalled = $false
            foreach ($match in $parenMatches) {
                if ($match.Value -match 'Installed') {
                    $isInstalled = $true
                    break
                }
            }

            if (-not $isInstalled) {
                continue
            }

            $version = $null
            if ($text -match "^$Platform\s+([0-9]+(?:\.[0-9]+)*)") {
                $version = $Matches[1]
            }

            if (-not $version) {
                continue
            }

            if (-not $results.ContainsKey($version)) {
                $results[$version] = [pscustomobject]@{
                    Version     = $version
                    Platform    = $Platform
                    DisplayName = $text
                    Source      = 'xcodes'
                }
            }
        }
    } catch {
        Write-Warning "Failed to parse xcodes runtimes output for ${Platform}: $($_.Exception.Message)"
    }

    return $results
}
