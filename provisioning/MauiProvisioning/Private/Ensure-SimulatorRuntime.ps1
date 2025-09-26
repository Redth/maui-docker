function Ensure-SimulatorRuntime {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('iOS', 'tvOS')]
        [string]$Platform,
        [Parameter(Mandatory=$true)]
        [string]$Version,
        [string]$DisplayName = ""
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "No $Platform simulator runtime version specified; skipping runtime installation"
        return $true
    }

    $context = Get-ProvisionContext
    $isDryRun = $context.DryRun

    $installedRuntimes = Get-XcodesSimulatorRuntimes -Platform $Platform
    if ($installedRuntimes.ContainsKey($Version)) {
        Write-Host "$Platform simulator runtime $Version already installed"
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = "$Platform $Version"
    }

    if ($isDryRun) {
        Write-Host "[DryRun] Would install $Platform simulator runtime '$DisplayName'"
        return $true
    }

    if (-not (Ensure-XcodesApp)) {
        Write-Warning "xcodes CLI is required to install $Platform simulator runtimes"
        return $false
    }

    try {
        Write-Host "Installing $Platform simulator runtime '$DisplayName'..."
        Invoke-ExternalCommand -Command "xcodes" -Arguments @("runtimes", "install", $DisplayName)
        return $true
    }
    catch {
        Write-Warning "Failed to install $Platform simulator runtime '$DisplayName': $($_.Exception.Message)"
        return $false
    }
}
