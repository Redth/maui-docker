$moduleRoot = Split-Path -Parent $PSCommandPath
$script:ModuleRoot = $moduleRoot
$script:BrewTapCache = $null

$privatePath = Join-Path $moduleRoot "Private"
if (Test-Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter *.ps1 | ForEach-Object { . $_.FullName }
}

if (Get-Command Set-ModuleRoot -ErrorAction SilentlyContinue) {
    Set-ModuleRoot -Path $moduleRoot
}

$publicPath = Join-Path $moduleRoot "Public"
$publicFunctions = @()
if (Test-Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter *.ps1 | ForEach-Object {
        . $_.FullName
        $publicFunctions += [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}

if ($publicFunctions.Count -gt 0) {
    Export-ModuleMember -Function $publicFunctions
}
