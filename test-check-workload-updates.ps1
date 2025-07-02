#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for check-workload-updates.ps1

.DESCRIPTION
    This script demonstrates how to test the check-workload-updates.ps1 script locally
    for development and debugging purposes.

.EXAMPLE
    .\test-check-workload-updates.ps1
#>

Write-Host "🧪 Testing check-workload-updates.ps1 script" -ForegroundColor Cyan
Write-Host ""

# Test 1: Basic functionality with object output
Write-Host "Test 1: Basic functionality test" -ForegroundColor Yellow
Write-Host "Running: ./check-workload-updates.ps1 -OutputFormat object"
Write-Host ""

try {
    $result = ./check-workload-updates.ps1 -OutputFormat object
    
    Write-Host "✅ Script executed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Results:" -ForegroundColor White
    Write-Host "  Latest Version: $($result.LatestVersion)" -ForegroundColor White
    Write-Host "  Dotnet Command Version: $($result.DotnetCommandWorkloadSetVersion)" -ForegroundColor White
    Write-Host "  Linux Tag: $($result.LinuxTag)" -ForegroundColor White
    Write-Host "  Windows Tag: $($result.WindowsTag)" -ForegroundColor White
    Write-Host "  Has Linux Build: $($result.HasLinuxBuild)" -ForegroundColor White
    Write-Host "  Has Windows Build: $($result.HasWindowsBuild)" -ForegroundColor White
    Write-Host "  Trigger Builds: $($result.TriggerBuilds)" -ForegroundColor White
    Write-Host "  New Version: $($result.NewVersion)" -ForegroundColor White
    Write-Host "  Docker Repository: $($result.DockerRepository)" -ForegroundColor White
    Write-Host "  .NET Version: $($result.DotnetVersion)" -ForegroundColor White
    
    if ($result.ErrorMessage) {
        Write-Host "  Error Message: $($result.ErrorMessage)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Test 1 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 50

# Test 2: Test with different repository
Write-Host "Test 2: Test with different Docker repository" -ForegroundColor Yellow
Write-Host "Running: ./check-workload-updates.ps1 -DockerRepository 'nonexistent/repo' -OutputFormat object"
Write-Host ""

try {
    $result2 = ./check-workload-updates.ps1 -DockerRepository "nonexistent/repo" -OutputFormat object
    
    Write-Host "✅ Script executed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Results:" -ForegroundColor White
    Write-Host "  Latest Version: $($result2.LatestVersion)" -ForegroundColor White
    Write-Host "  Dotnet Command Version: $($result2.DotnetCommandWorkloadSetVersion)" -ForegroundColor White
    Write-Host "  Linux Tag: $($result2.LinuxTag)" -ForegroundColor White
    Write-Host "  Windows Tag: $($result2.WindowsTag)" -ForegroundColor White
    Write-Host "  Has Linux Build: $($result2.HasLinuxBuild)" -ForegroundColor White
    Write-Host "  Has Windows Build: $($result2.HasWindowsBuild)" -ForegroundColor White
    Write-Host "  Trigger Builds: $($result2.TriggerBuilds)" -ForegroundColor White
    Write-Host "  New Version: $($result2.NewVersion)" -ForegroundColor White
    Write-Host "  Docker Repository: $($result2.DockerRepository)" -ForegroundColor White
    
    if ($result2.ErrorMessage) {
        Write-Host "  Error Message: $($result2.ErrorMessage)" -ForegroundColor Yellow
        Write-Host "  ℹ️ This is expected for a non-existent repository" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "❌ Test 2 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=" * 50

# Test 3: Test GitHub Actions output format
Write-Host "Test 3: Test GitHub Actions output format" -ForegroundColor Yellow
Write-Host "Running: ./check-workload-updates.ps1 -OutputFormat github-actions"
Write-Host ""

# Create a temporary GITHUB_OUTPUT file for testing
$tempOutput = [System.IO.Path]::GetTempFileName()
$env:GITHUB_OUTPUT = $tempOutput

try {
    ./check-workload-updates.ps1 -OutputFormat github-actions
    
    Write-Host "✅ Script executed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "GitHub Actions outputs:" -ForegroundColor White
    
    if (Test-Path $tempOutput) {
        $outputs = Get-Content $tempOutput
        foreach ($output in $outputs) {
            Write-Host "  $output" -ForegroundColor White
        }
    } else {
        Write-Host "  No outputs file created" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Test 3 failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # Clean up
    if (Test-Path $tempOutput) {
        Remove-Item $tempOutput -Force
    }
    Remove-Item env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "🎉 Testing complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Tips for local development:" -ForegroundColor Cyan
Write-Host "  - Use '-OutputFormat object' to get structured PowerShell output"
Write-Host "  - Use '-DockerRepository your-repo/image' to test with your own repositories"
Write-Host "  - Check the script directly: Get-Help ./check-workload-updates.ps1 -Full"
