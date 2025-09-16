function Ensure-AndroidPackage {
    param(
        [string]$PackageId,
        [hashtable]$InstalledPackages,
        [ref]$ChangesMade,
        [string]$AndroidHome
    )

    if ((-not (Test-DryRun)) -and $InstalledPackages.ContainsKey($PackageId)) {
        Write-Host "Android SDK package '$PackageId' already installed"
        return
    }

    if (Test-DryRun) {
        Write-Host "[DryRun] Would install Android SDK package '$PackageId'"
        return
    }

    $arguments = @("sdk", "install", "--package", $PackageId)
    if ($AndroidHome) {
        $arguments += @("--home", $AndroidHome)
    }

    & "android" @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Android SDK package $PackageId"
    }

    $InstalledPackages[$PackageId] = @{}
    $ChangesMade.Value = $true
}
