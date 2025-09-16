function Ensure-XcodesApp {
    param()

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun

    # Check if xcodes is already installed
    if (Get-Command xcodes -ErrorAction SilentlyContinue) {
        Write-Host "xcodes app already installed"
        return $true
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install xcodes app via Homebrew"
        return $true
    }

    try {
        Write-Host "Installing xcodes app via Homebrew..."
        Invoke-ExternalCommand -Command "brew" -Arguments @("install", "xcodes")
        return $true
    } catch {
        Write-Warning "Failed to install xcodes app: $($_.Exception.Message)"
        return $false
    }
}