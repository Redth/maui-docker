function Get-InstalledDotnetSdkVersions {
    param(
        [string]$InstallDir,
        [string]$Channel
    )

    $versions = @()

    if (Test-DryRun) {
        return $versions
    }

    $sdkRoot = Join-Path $InstallDir "sdk"
    if (-not (Test-Path $sdkRoot)) {
        return $versions
    }

    $pattern = "^$([regex]::Escape($Channel))\."
    Get-ChildItem -Path $sdkRoot -Directory | Where-Object { $_.Name -match $pattern } | ForEach-Object { $versions += $_.Name }
    return $versions
}
