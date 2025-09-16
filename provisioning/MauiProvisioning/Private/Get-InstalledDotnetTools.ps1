function Get-InstalledDotnetTools {
    param([string]$DotnetPath)

    $tools = @{}

    try {
        $jsonOutput = & $DotnetPath tool list -g --machine-readable 2>$null
        if ($LASTEXITCODE -eq 0 -and $jsonOutput) {
            $parsed = $jsonOutput | ConvertFrom-Json -ErrorAction Stop
            if ($parsed.tools) {
                foreach ($tool in $parsed.tools) {
                    $id = $tool.packageId
                    if ($id) {
                        $tools[$id] = $tool
                    }
                }
            }
            return $tools
        }
    } catch {
        Write-Warning "Failed to read machine-readable dotnet tool list: $($_.Exception.Message)"
    }

    try {
        $textOutput = & $DotnetPath tool list -g 2>$null
        if ($LASTEXITCODE -eq 0 -and $textOutput) {
            foreach ($line in $textOutput) {
                if ($line -match '^([\w\.\-]+)\s+([\d\.]+)') {
                    $tools[$Matches[1]] = @{ Version = $Matches[2] }
                }
            }
        }
    } catch {
        Write-Warning "Failed to read dotnet tool list: $($_.Exception.Message)"
    }

    return $tools
}
