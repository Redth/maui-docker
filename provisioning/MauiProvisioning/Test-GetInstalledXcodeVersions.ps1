Param(
    [switch]$AsJson
)

$moduleRoot = Split-Path -Parent $PSCommandPath
$manifestPath = Join-Path $moduleRoot 'MauiProvisioning.psd1'

if (-not (Test-Path $manifestPath)) {
    Write-Error "Cannot locate MauiProvisioning module manifest at $manifestPath"
    exit 1
}

# Load module to ensure shared helpers are available
Import-Module $manifestPath -Force

# Ensure the private function under test is loaded into the current scope
$privateScript = Join-Path $moduleRoot 'Private/Get-InstalledXcodeVersions.ps1'
if (-not (Test-Path $privateScript)) {
    Write-Error "Cannot locate Get-InstalledXcodeVersions script at $privateScript"
    exit 1
}
. $privateScript

try {
    $versions = Get-InstalledXcodeVersions
} catch {
    Write-Error "Failed to invoke Get-InstalledXcodeVersions: $($_.Exception.Message)"
    exit 1
}

if (-not $versions -or $versions.Count -eq 0) {
    Write-Host "No Xcode installations detected."
    return
}

$results = $versions.GetEnumerator() |
    Sort-Object Key |
    ForEach-Object {
        [pscustomobject]@{
            Version = $_.Value.Version
            Selected = $_.Value.IsSelected
            Path = $_.Value.Path
        }
    }

if ($AsJson) {
    $results | ConvertTo-Json -Depth 3
} else {
    $results | Format-Table -AutoSize
}
