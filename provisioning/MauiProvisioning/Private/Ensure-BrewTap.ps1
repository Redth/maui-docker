function Ensure-BrewTap {
    param([string]$Tap)

    if (Test-DryRun) {
        Write-Host "[DryRun] Would ensure Homebrew tap '$Tap' is available"
        return
    }

    if (-not $script:BrewTapCache) {
        try {
            $script:BrewTapCache = (& brew tap 2>$null)
        } catch {
            $script:BrewTapCache = @()
        }
    }

    $tapList = @()
    if ($script:BrewTapCache) {
        $tapList = $script:BrewTapCache -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    if ($tapList -contains $Tap) {
        Write-Host "Homebrew tap '$Tap' already configured"
        return
    }

    Invoke-ExternalCommand -Command "brew" -Arguments @("tap", $Tap)
    $script:BrewTapCache = ($tapList + $Tap) -join "`n"
}
