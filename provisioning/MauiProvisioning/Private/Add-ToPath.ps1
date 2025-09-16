function Add-ToPath {
    param([string]$PathToAdd)

    if ([string]::IsNullOrEmpty($PathToAdd)) {
        return
    }

    $pathSeparator = [System.IO.Path]::PathSeparator
    $currentEntries = $env:PATH -split $pathSeparator
    if (-not ($currentEntries -contains $PathToAdd)) {
        $env:PATH = "$PathToAdd$pathSeparator$($env:PATH)"
    }
}
