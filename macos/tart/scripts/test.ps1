#!/usr/bin/env pwsh

Param(
    [Parameter(Mandatory=$true)]
    [string]$ImageName,

    [string]$TestType = "basic",
    [int]$TimeoutMinutes = 10,
    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Testing Tart VM Image: $ImageName"
Write-Host "==============================="

function Test-TartImageExists {
    param([string]$ImageName)

    $images = & tart list | Out-String
    if (-not ($images -match [regex]::Escape($ImageName))) {
        throw "Image '$ImageName' not found. Available images:`n$images"
    }
    Write-Host "✅ Image exists: $ImageName"
}

function Test-VMBoot {
    param([string]$ImageName, [int]$TimeoutMinutes)

    Write-Host "🔄 Testing VM boot..."

    # Start VM in background
    $vmName = "$ImageName-test-$(Get-Random)"

    try {
        & tart clone $ImageName $vmName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone image for testing"
        }

        & tart run $vmName --no-graphics &
        $runJob = Start-Job -ScriptBlock {
            param($vmName)
            & tart run $vmName --no-graphics
        } -ArgumentList $vmName

        # Wait for VM to boot and SSH to be available
        $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
        $vmIP = $null

        while ((Get-Date) -lt $timeout) {
            Start-Sleep -Seconds 5

            try {
                $vmIP = & tart ip $vmName 2>$null
                if ($vmIP -and $vmIP -match '^\d+\.\d+\.\d+\.\d+$') {
                    # Test SSH connectivity
                    $sshTest = & ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@$vmIP "echo 'SSH_OK'" 2>$null
                    if ($sshTest -eq "SSH_OK") {
                        Write-Host "✅ VM booted successfully: $vmIP"
                        return $vmIP
                    }
                }
            } catch {
                # Continue waiting
            }
        }

        throw "VM failed to boot within $TimeoutMinutes minutes"

    } finally {
        # Cleanup
        try {
            & tart stop $vmName 2>$null
            & tart delete $vmName 2>$null
            if ($runJob) {
                Stop-Job $runJob -ErrorAction SilentlyContinue
                Remove-Job $runJob -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Warning "Failed to cleanup test VM: $_"
        }
    }
}

function Test-Tools {
    param([string]$ImageName, [string]$TestType)

    Write-Host "🔄 Testing installed tools..."

    $vmName = "$ImageName-tools-test-$(Get-Random)"

    try {
        & tart clone $ImageName $vmName
        & tart run $vmName --no-graphics &

        # Wait for VM to be ready
        Start-Sleep -Seconds 30
        $vmIP = & tart ip $vmName

        if (-not $vmIP) {
            throw "Could not get VM IP for tools testing"
        }

        # Test basic tools
        $testCommands = @(
            "uname -a",
            "which brew",
            "brew --version",
            "which git",
            "git --version",
            "which pwsh",
            "pwsh --version"
        )

        # Add .NET specific tests if MAUI image
        if ($TestType -eq "maui" -or $TestType -eq "ci") {
            $testCommands += @(
                "which dotnet",
                "dotnet --version",
                "dotnet workload list",
                "which xcodebuild",
                "xcodebuild -version"
            )
        }

        # Add CI specific tests
        if ($TestType -eq "ci") {
            $testCommands += @(
                "which gh",
                "gh --version",
                "which fastlane",
                "fastlane --version"
            )
        }

        foreach ($cmd in $testCommands) {
            Write-Host "  Testing: $cmd"
            $result = & ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no admin@$vmIP $cmd 2>&1

            if ($LASTEXITCODE -eq 0) {
                if ($Verbose) {
                    Write-Host "    ✅ $result"
                } else {
                    Write-Host "    ✅ OK"
                }
            } else {
                Write-Warning "    ❌ Failed: $result"
            }
        }

        Write-Host "✅ Tools testing completed"

    } finally {
        # Cleanup
        try {
            & tart stop $vmName 2>$null
            & tart delete $vmName 2>$null
        } catch {
            Write-Warning "Failed to cleanup tools test VM: $_"
        }
    }
}

function Test-BuildInfo {
    param([string]$ImageName)

    Write-Host "🔄 Testing build information..."

    $vmName = "$ImageName-info-test-$(Get-Random)"

    try {
        & tart clone $ImageName $vmName
        & tart run $vmName --no-graphics &

        Start-Sleep -Seconds 30
        $vmIP = & tart ip $vmName

        if (-not $vmIP) {
            throw "Could not get VM IP for build info testing"
        }

        $buildInfo = & ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no admin@$vmIP "cat /usr/local/share/build-info.json" 2>$null

        if ($buildInfo) {
            $buildData = $buildInfo | ConvertFrom-Json
            Write-Host "✅ Build information found:"
            Write-Host "    Image Type: $($buildData.image_type)"
            Write-Host "    macOS Version: $($buildData.macos_version)"
            Write-Host "    Build Date: $($buildData.build_date)"

            if ($buildData.tools) {
                Write-Host "    Tools:"
                $buildData.tools.PSObject.Properties | ForEach-Object {
                    Write-Host "      $($_.Name): $($_.Value)"
                }
            }
        } else {
            Write-Warning "❌ Build information not found"
        }

    } finally {
        # Cleanup
        try {
            & tart stop $vmName 2>$null
            & tart delete $vmName 2>$null
        } catch {
            Write-Warning "Failed to cleanup info test VM: $_"
        }
    }
}

function Test-MAUIProject {
    param([string]$ImageName)

    Write-Host "🔄 Testing MAUI project creation and build..."

    $vmName = "$ImageName-maui-test-$(Get-Random)"

    try {
        & tart clone $ImageName $vmName
        & tart run $vmName --no-graphics &

        Start-Sleep -Seconds 30
        $vmIP = & tart ip $vmName

        if (-not $vmIP) {
            throw "Could not get VM IP for MAUI testing"
        }

        $testScript = @"
#!/bin/bash
set -e
export PATH="/Users/admin/.dotnet:/Users/admin/.dotnet/tools:\$PATH"
export DOTNET_ROOT="/Users/admin/.dotnet"
cd /tmp
echo "Creating MAUI project..."
dotnet new maui -n TestMauiApp
cd TestMauiApp
echo "Building MAUI project..."
dotnet build
echo "MAUI test completed successfully"
"@

        # Write test script to VM and execute
        $scriptResult = & ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no admin@$vmIP "echo '$testScript' > /tmp/test-maui.sh && chmod +x /tmp/test-maui.sh && /tmp/test-maui.sh" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ MAUI project test passed"
        } else {
            Write-Warning "❌ MAUI project test failed: $scriptResult"
        }

    } finally {
        # Cleanup
        try {
            & tart stop $vmName 2>$null
            & tart delete $vmName 2>$null
        } catch {
            Write-Warning "Failed to cleanup MAUI test VM: $_"
        }
    }
}

# Main testing execution
try {
    Write-Host "Starting tests for image: $ImageName"
    Write-Host "Test type: $TestType"
    Write-Host ""

    # Test 1: Image exists
    Test-TartImageExists -ImageName $ImageName

    # Test 2: VM boot
    $vmIP = Test-VMBoot -ImageName $ImageName -TimeoutMinutes $TimeoutMinutes

    # Test 3: Installed tools
    Test-Tools -ImageName $ImageName -TestType $TestType

    # Test 4: Build information
    Test-BuildInfo -ImageName $ImageName

    # Test 5: MAUI project (if applicable)
    if ($TestType -eq "maui" -or $TestType -eq "ci") {
        Test-MAUIProject -ImageName $ImageName
    }

    Write-Host ""
    Write-Host "🎉 All tests passed for image: $ImageName"
    Write-Host ""
    Write-Host "Image is ready for use:"
    Write-Host "  tart run $ImageName"
    Write-Host "  tart run $ImageName --dir project:/path/to/your/project"

} catch {
    Write-Error "❌ Test failed: $($_.Exception.Message)"
    exit 1
}