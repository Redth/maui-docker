function Ensure-TvOsSimulatorRuntime {
    param(
        [string]$Version,
        [string]$DisplayName = ""
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "No tvOS simulator runtime version specified; skipping runtime installation"
        return $true
    }

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun

    $installedRuntimes = Get-InstalledTvSimulatorRuntimes
    if ($installedRuntimes.ContainsKey($Version)) {
        Write-Host "tvOS simulator runtime $Version already installed"
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = "tvOS $Version Simulator"
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install tvOS simulator runtime '$DisplayName'"
        return $true
    }

    if (-not (Ensure-XcodesApp)) {
        Write-Warning "xcodes CLI is required to install tvOS simulator runtimes"
        return $false
    }

    try {
        Write-Host "Installing tvOS simulator runtime '$DisplayName'..."
        Invoke-ExternalCommand -Command "xcodes" -Arguments @("runtimes", "--install", $DisplayName)
        return $true
    }
    catch {
        Write-Warning "Failed to install tvOS simulator runtime '$DisplayName': $($_.Exception.Message)"
        return $false
    }
}
