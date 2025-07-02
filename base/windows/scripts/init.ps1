# Base initialization script for MAUI development environment
Write-Host "MAUI Base Image - Windows"
Write-Host "========================="

# Check for and execute custom initialization script if it exists
$initPwshPath = $env:INIT_PWSH_SCRIPT

if (Test-Path $initPwshPath) {
    Write-Host "Found custom initialization script at $initPwshPath, executing..."
    try {
        & $initPwshPath
        Write-Host "Custom initialization script executed successfully."
    } catch {
        Write-Host "Error executing custom initialization script: $_"
    }
}

Write-Host "Base initialization complete."
Write-Host "This is a MAUI development base image with .NET $($env:DOTNET_VERSION), Android SDK, and Java $($env:JDK_MAJOR_VERSION)"
Write-Host "You can now run your MAUI Android development tasks."
