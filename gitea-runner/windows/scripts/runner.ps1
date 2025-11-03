# PowerShell script for Gitea Actions runner registration and execution

# Check for and execute initialization script if it exists
$initPwshPath = $env:INIT_PWSH_SCRIPT

if (Test-Path $initPwshPath) {
    Write-Host "Found initialization script at $initPwshPath, executing..."
    try {
        & $initPwshPath
        Write-Host "Initialization script executed successfully."
    } catch {
        Write-Host "Error executing initialization script: $_"
    }
}

# Environment variables
$GITEA_INSTANCE_URL = $env:GITEA_INSTANCE_URL
$GITEA_RUNNER_TOKEN = $env:GITEA_RUNNER_TOKEN
$GITEA_RUNNER_NAME = $env:GITEA_RUNNER_NAME

Write-Host "GITEA_INSTANCE_URL: $GITEA_INSTANCE_URL"

# Check if required environment variables are set
if ([string]::IsNullOrEmpty($GITEA_INSTANCE_URL)) {
    Write-Error "ERROR: GITEA_INSTANCE_URL environment variable is not set"
    exit 1
}

if ([string]::IsNullOrEmpty($GITEA_RUNNER_TOKEN)) {
    Write-Error "ERROR: GITEA_RUNNER_TOKEN environment variable is not set"
    exit 1
}

# Change to runner directory
Set-Location -Path "C:\gitea-runner"

# Generate runner name if not provided
$RANDOM_RUNNER_SUFFIX = if ($env:RANDOM_RUNNER_SUFFIX) { $env:RANDOM_RUNNER_SUFFIX } else { "true" }
$RUNNER_NAME_PREFIX = if ($env:GITEA_RUNNER_NAME_PREFIX) { $env:GITEA_RUNNER_NAME_PREFIX } else { "gitea-runner" }

if ([string]::IsNullOrEmpty($GITEA_RUNNER_NAME)) {
    if ($RANDOM_RUNNER_SUFFIX -ne "true") {
        if (Test-Path -Path "C:\Windows\System32\hostname.exe") {
            # Use hostname if available
            $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(hostname)"
            Write-Host "RANDOM_RUNNER_SUFFIX is $RANDOM_RUNNER_SUFFIX. Using hostname for runner name: $_RUNNER_NAME"
        } else {
            # Generate random suffix if hostname not available
            $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(New-Guid | Select-Object -ExpandProperty Guid)"
            Write-Host "RANDOM_RUNNER_SUFFIX is $RANDOM_RUNNER_SUFFIX but hostname command not available. Using random GUID."
        }
    } else {
        # Generate random suffix
        $_RUNNER_NAME = "$RUNNER_NAME_PREFIX-$(New-Guid | Select-Object -ExpandProperty Guid)"
    }
} else {
    $_RUNNER_NAME = $GITEA_RUNNER_NAME
}

# Set runner labels
$_LABELS = if ($env:GITEA_RUNNER_LABELS) { $env:GITEA_RUNNER_LABELS } else { "maui,windows,amd64" }

Write-Host "Registering Gitea runner: $_RUNNER_NAME"
Write-Host "Labels: $_LABELS"

# Register the runner if not already registered
if (-not (Test-Path -Path ".runner")) {
    Write-Host "Registering runner with Gitea..."

    $registerArgs = @(
        "register",
        "--instance", $GITEA_INSTANCE_URL,
        "--token", $GITEA_RUNNER_TOKEN,
        "--name", $_RUNNER_NAME,
        "--labels", $_LABELS,
        "--no-interactive"
    )

    & .\act_runner.exe @registerArgs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "ERROR: Failed to register runner with Gitea"
        exit 1
    }

    Write-Host "Runner registered successfully"
} else {
    Write-Host "Runner already registered (found .runner file)"
}

# Define cleanup function for graceful exit
function Cleanup {
    Write-Host "Shutting down Gitea runner..."
    # Gitea runner doesn't have a built-in removal command like GitHub
    # The runner will just stop and can be removed from Gitea UI if needed
}

# Set up cleanup on script termination
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup } -SupportEvent

# Trap Ctrl+C
[Console]::TreatControlCAsInput = $true
$timer = New-Object System.Timers.Timer
$timer.Interval = 1000
$timer.Start()
Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq "C" -and $key.Modifiers -eq "Control") {
            Write-Host "Ctrl+C pressed, cleaning up..."
            Cleanup
            exit 130
        }
    }
} | Out-Null

# Start the runner daemon
Write-Host "Starting Gitea runner daemon..."
& .\act_runner.exe daemon
