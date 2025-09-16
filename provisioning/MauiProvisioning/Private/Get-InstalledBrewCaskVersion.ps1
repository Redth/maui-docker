function Get-InstalledBrewCaskVersion {
    param([string]$Cask)

    try {
        $output = & brew list --cask --versions $Cask 2>$null
    } catch {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    $parts = $output -split '\s+'
    if ($parts.Length -ge 2) {
        return $parts[1]
    }

    return $null
}
