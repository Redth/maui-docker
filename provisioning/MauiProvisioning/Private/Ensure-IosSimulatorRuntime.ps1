function Ensure-IosSimulatorRuntime {
    param(
        [string]$Version,
        [string]$DisplayName = ""
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "No iOS simulator runtime version specified; skipping runtime installation"
        return $true
    }

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun

    $installedRuntimes = Get-InstalledIosSimulatorRuntimes
    if ($installedRuntimes.ContainsKey($Version)) {
        Write-Host "iOS simulator runtime $Version already installed"
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = "iOS $Version Simulator"
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install iOS simulator runtime '$DisplayName'"
        return $true
    }

    if (-not (Ensure-XcodesApp)) {
        Write-Warning "xcodes CLI is required to install iOS simulator runtimes"
        return $false
    }

    try {
        Write-Host "Installing iOS simulator runtime '$DisplayName'..."
        Invoke-ExternalCommand -Command "xcodes" -Arguments @("runtimes", "--install", $DisplayName)
        return $true
    }
    catch {
        Write-Warning "Failed to install iOS simulator runtime '$DisplayName': $($_.Exception.Message)"
        return $false
    }
}
