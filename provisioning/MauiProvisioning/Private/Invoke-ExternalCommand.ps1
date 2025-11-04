function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path
    )

    $formattedArgs = $Arguments | ForEach-Object {
        if ($_ -match '\s') {
            '"{0}"' -f ($_ -replace '"', '\"')
        } else {
            $_
        }
    }

    Write-Host "Running: $Command $($formattedArgs -join ' ')"

    if (Test-DryRun) {
        Write-Host "[DryRun] Skipping execution"
        return
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Command
    foreach ($arg in $Arguments) {
        $null = $startInfo.ArgumentList.Add($arg)
    }
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "Command '$Command' exited with code $($process.ExitCode)"
    }
}
