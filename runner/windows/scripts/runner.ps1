# PowerShell script for GitHub Actions runner registration and execution
# filepath: x:\code\maui-docker\github-actions-runner\windows\scripts\runner.ps1

# Environment variables
$GITHUB_ORG = $env:GITHUB_ORG
$GITHUB_REPO = $env:GITHUB_REPO
$GITHUB_TOKEN = $env:GITHUB_TOKEN

Write-Host "GITHUB_ORG: $GITHUB_ORG"
Write-Host "GITHUB_REPO: $GITHUB_REPO"

# Check if GitHub repo is specified and use the appropriate API endpoint
if ([string]::IsNullOrEmpty($GITHUB_REPO)) {
    Write-Host "No repository specified, registering runner at organization level"
    $headers = @{
        Authorization = "Bearer $GITHUB_TOKEN"
        Accept = "application/vnd.github+json"
    }
    $response = Invoke-RestMethod -Uri "https://api.github.com/orgs/$GITHUB_ORG/actions/runners/registration-token" -Method Post -Headers $headers
    $REG_TOKEN = $response.token
    $RUNNER_URL = "https://github.com/$GITHUB_ORG"
} else {
    Write-Host "Repository specified, registering runner at repository level"
    $headers = @{
        Authorization = "Bearer $GITHUB_TOKEN"
        Accept = "application/vnd.github+json"
    }
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/runners/registration-token" -Method Post -Headers $headers
    $REG_TOKEN = $response.token
    $RUNNER_URL = "https://github.com/$GITHUB_ORG/$GITHUB_REPO"
}

# Check if the registration token is empty
if ([string]::IsNullOrEmpty($REG_TOKEN)) {
    Write-Error "ERROR: Failed to obtain registration token. Please check your GitHub token, organization name, and repository name (if provided)."
    Write-Error "Response from GitHub API might indicate an authentication or permission issue."
    exit 1
}

# Change to runner directory 
Set-Location -Path "C:\actions-runner"

# Set runner name with appropriate suffix
$RANDOM_RUNNER_SUFFIX = if ($env:RANDOM_RUNNER_SUFFIX) { $env:RANDOM_RUNNER_SUFFIX } else { "true" }
$RUNNER_NAME_PREFIX = if ($env:RUNNER_NAME_PREFIX) { $env:RUNNER_NAME_PREFIX } else { "github-runner" }

# Generate runner name
if ($env:RUNNER_NAME) {
    $_RUNNER_NAME = $env:RUNNER_NAME
} else {
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
}

# Set runner work directory
$_RUNNER_WORKDIR = if ($env:RUNNER_WORKDIR) { $env:RUNNER_WORKDIR } else { "C:\actions-runner\_work\$_RUNNER_NAME" }
$_LABELS = if ($env:LABELS) { $env:LABELS } else { "default" }
$_RUNNER_GROUP = if ($env:RUNNER_GROUP) { $env:RUNNER_GROUP } else { "Default" }

# Prepare arguments
$configArgs = @(
    "--url", $RUNNER_URL,
    "--token", $REG_TOKEN,
    "--name", $_RUNNER_NAME,
    "--work", $_RUNNER_WORKDIR,
    "--labels", $_LABELS,
    "--runnergroup", $_RUNNER_GROUP,
    "--unattended",
    "--replace"
)

# Add conditional arguments
if ($env:EPHEMERAL) {
    Write-Host "Ephemeral option is enabled"
    $configArgs += "--ephemeral"
}

if ($env:DISABLE_AUTO_UPDATE) {
    Write-Host "Disable auto update option is enabled"
    $configArgs += "--disableupdate"
}

if ($env:NO_DEFAULT_LABELS) {
    Write-Host "Disable adding the default self-hosted, platform, and architecture labels"
    $configArgs += "--no-default-labels"
}

Write-Host "Configuring runner"
& .\config.cmd @configArgs

# Create the work directory if it doesn't exist
if (-not (Test-Path -Path $_RUNNER_WORKDIR)) {
    New-Item -Path $_RUNNER_WORKDIR -ItemType Directory -Force | Out-Null
}

# Define cleanup function for graceful exit
function Cleanup {
    Write-Host "Removing runner..."
    & .\config.cmd remove --unattended --token $REG_TOKEN
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

# Start the runner
Write-Host "Starting runner..."
& .\run.cmd
