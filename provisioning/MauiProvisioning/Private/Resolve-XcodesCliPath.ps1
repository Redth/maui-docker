function Resolve-XcodesCliPath {
    param()

    $command = Get-Command xcodes -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $homebrewPath = "/opt/homebrew/bin/xcodes"
    if (Test-Path $homebrewPath) {
        return $homebrewPath
    }

    $usrLocalPath = "/usr/local/bin/xcodes"
    if (Test-Path $usrLocalPath) {
        return $usrLocalPath
    }

    $cellarRoot = "/opt/homebrew/Cellar/xcodes"
    if (Test-Path $cellarRoot) {
        $latest = Get-ChildItem -Path $cellarRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) {
            $candidate = Join-Path $latest.FullName "bin/xcodes"
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }

    return $null
}
