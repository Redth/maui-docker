function Get-AndroidPackageAlias {
    param([string]$PackageId)

    if ([string]::IsNullOrWhiteSpace($PackageId)) {
        return $null
    }

    if ($PackageId -match '^platforms;android-(\d+)\.\d+$') {
        $majorVersion = $Matches[1]
        return "platforms;android-$majorVersion"
    }

    return $null
}

function Ensure-AndroidPackage {
    param(
        [string]$PackageId,
        [hashtable]$InstalledPackages,
        [ref]$ChangesMade,
        [string]$AndroidHome
    )

    $packageIdsToTry = @()
    $alias = Get-AndroidPackageAlias -PackageId $PackageId
    if ($alias) {
        $packageIdsToTry += $alias
    }
    if ($PackageId) {
        $packageIdsToTry += $PackageId
    }

    foreach ($candidateId in $packageIdsToTry) {
        if (-not $candidateId) {
            continue
        }

        if ((-not (Test-DryRun)) -and $InstalledPackages.ContainsKey($candidateId)) {
            Write-Host "Android SDK package '$candidateId' already installed"
            if ($candidateId -ne $PackageId -and -not $InstalledPackages.ContainsKey($PackageId)) {
                $InstalledPackages[$PackageId] = $InstalledPackages[$candidateId]
            }
            return
        }

        if (Test-DryRun) {
            Write-Host "[DryRun] Would install Android SDK package '$candidateId'"
            if ($candidateId -ne $PackageId) {
                Write-Host "[DryRun] (alias for requested package '$PackageId')"
            }
            return
        }

        $arguments = @("sdk", "install", "--package", $candidateId)
        if ($AndroidHome) {
            $arguments += @("--home", $AndroidHome)
        }

        & "android" @arguments
        if ($LASTEXITCODE -ne 0) {
            if ($candidateId -ne $packageIdsToTry[-1]) {
                Write-Warning "Failed to install Android SDK package '$candidateId', trying fallback if available..."
                continue
            }
            throw "Failed to install Android SDK package $candidateId"
        }

        Write-Host "Installed Android SDK package '$candidateId'"
        $InstalledPackages[$candidateId] = @{}
        if ($candidateId -ne $PackageId -and -not $InstalledPackages.ContainsKey($PackageId)) {
            $InstalledPackages[$PackageId] = @{}
        }
        $ChangesMade.Value = $true
        return
    }
}
