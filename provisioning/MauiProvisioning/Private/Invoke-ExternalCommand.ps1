function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-Location).Path
    )

    Write-Host "Running: $Command $($Arguments -join ' ')"

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
