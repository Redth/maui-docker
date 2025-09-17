#!/usr/bin/env pwsh

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("list", "run", "stop", "delete", "info", "ssh", "clean")]
    [string]$Action,

    [string]$ImageName = "",
    [string]$ProjectPath = "",
    [switch]$All
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-MAUIImages {
    $allImages = & tart list | Out-String
    $lines = $allImages -split "`n" | Where-Object { $_ -match "maui-" }
    return $lines
}

function Show-ImageList {
    Write-Host "Available MAUI Tart Images:"
    Write-Host "=========================="

    $images = Get-MAUIImages
    if ($images.Count -eq 0) {
        Write-Host "No MAUI images found."
        Write-Host "Run: pwsh ./scripts/quick-start.ps1 to build images"
        return
    }

    foreach ($image in $images) {
        Write-Host $image
    }
}

function Start-VM {
    param([string]$ImageName, [string]$ProjectPath)

    if (-not $ImageName) {
        $images = Get-MAUIImages
        if ($images.Count -eq 0) {
            throw "No MAUI images available"
        }

        Write-Host "Available images:"
        for ($i = 0; $i -lt $images.Count; $i++) {
            Write-Host "  $($i + 1). $($images[$i])"
        }

        $selection = Read-Host "Select image number"
        $index = [int]$selection - 1

        if ($index -lt 0 -or $index -ge $images.Count) {
            throw "Invalid selection"
        }

        $ImageName = ($images[$index] -split '\s+')[0]
    }

    $runArgs = @($ImageName)

    if ($ProjectPath) {
        if (-not (Test-Path $ProjectPath)) {
            throw "Project path does not exist: $ProjectPath"
        }

        $resolvedPath = Resolve-Path $ProjectPath
        $runArgs += "--dir", "project:$resolvedPath"

        Write-Host "Starting VM with project mounted..."
        Write-Host "VM: $ImageName"
        Write-Host "Project: $resolvedPath"
        Write-Host ""
        Write-Host "Inside the VM, access your project at:"
        Write-Host "  cd '/Volumes/My Shared Files/project'"
    } else {
        Write-Host "Starting VM: $ImageName"
    }

    & tart run @runArgs
}

function Stop-VM {
    param([string]$ImageName, [bool]$All)

    if ($All) {
        $runningVMs = & tart list | Where-Object { $_ -match "running" -and $_ -match "maui-" }
        if ($runningVMs.Count -eq 0) {
            Write-Host "No running MAUI VMs found"
            return
        }

        foreach ($vm in $runningVMs) {
            $vmName = ($vm -split '\s+')[0]
            Write-Host "Stopping: $vmName"
            & tart stop $vmName
        }
    } else {
        if (-not $ImageName) {
            throw "Image name required when not using -All"
        }

        Write-Host "Stopping: $ImageName"
        & tart stop $ImageName
    }
}

function Remove-VM {
    param([string]$ImageName, [bool]$All)

    if ($All) {
        $mauiImages = Get-MAUIImages
        if ($mauiImages.Count -eq 0) {
            Write-Host "No MAUI images found"
            return
        }

        $confirm = Read-Host "Delete ALL MAUI images? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Cancelled"
            return
        }

        foreach ($image in $mauiImages) {
            $imageName = ($image -split '\s+')[0]
            Write-Host "Deleting: $imageName"
            & tart delete $imageName
        }
    } else {
        if (-not $ImageName) {
            throw "Image name required when not using -All"
        }

        $confirm = Read-Host "Delete image '$ImageName'? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Cancelled"
            return
        }

        Write-Host "Deleting: $ImageName"
        & tart delete $ImageName
    }
}

function Show-VMInfo {
    param([string]$ImageName)

    if (-not $ImageName) {
        $images = Get-MAUIImages
        if ($images.Count -eq 0) {
            throw "No MAUI images available"
        }

        Write-Host "Select image for detailed info:"
        for ($i = 0; $i -lt $images.Count; $i++) {
            Write-Host "  $($i + 1). $($images[$i])"
        }

        $selection = Read-Host "Select image number"
        $index = [int]$selection - 1
        $ImageName = ($images[$index] -split '\s+')[0]
    }

    Write-Host "VM Information: $ImageName"
    Write-Host "============================="

    # Basic VM info
    & tart get $ImageName

    # Try to get build info if VM is running
    try {
        $vmIP = & tart ip $ImageName 2>$null
        if ($vmIP) {
            Write-Host ""
            Write-Host "Build Information:"
            Write-Host "=================="
            $buildInfo = & ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no admin@$vmIP "cat /usr/local/share/build-info.json 2>/dev/null" 2>$null

            if ($buildInfo) {
                $buildData = $buildInfo | ConvertFrom-Json
                $buildData | ConvertTo-Json -Depth 3 | Write-Host
            } else {
                Write-Host "Build info not available (VM may not be running)"
            }
        }
    } catch {
        Write-Host "Could not retrieve runtime information"
    }
}

function Connect-SSH {
    param([string]$ImageName)

    if (-not $ImageName) {
        $runningVMs = & tart list | Where-Object { $_ -match "running" -and $_ -match "maui-" }
        if ($runningVMs.Count -eq 0) {
            throw "No running MAUI VMs found"
        }

        if ($runningVMs.Count -eq 1) {
            $ImageName = ($runningVMs[0] -split '\s+')[0]
        } else {
            Write-Host "Multiple VMs running, select one:"
            for ($i = 0; $i -lt $runningVMs.Count; $i++) {
                Write-Host "  $($i + 1). $($runningVMs[$i])"
            }

            $selection = Read-Host "Select VM number"
            $index = [int]$selection - 1
            $ImageName = ($runningVMs[$index] -split '\s+')[0]
        }
    }

    $vmIP = & tart ip $ImageName 2>$null
    if (-not $vmIP) {
        throw "Could not get IP for VM: $ImageName (is it running?)"
    }

    Write-Host "Connecting to $ImageName at $vmIP..."
    & ssh -o StrictHostKeyChecking=no admin@$vmIP
}

function Clean-Environment {
    Write-Host "Cleaning Tart environment..."

    # Stop all running MAUI VMs
    Write-Host "Stopping running VMs..."
    Stop-VM -All $true

    # Clean up any orphaned processes
    Write-Host "Cleaning up processes..."
    $tartProcesses = Get-Process | Where-Object { $_.ProcessName -like "*tart*" }
    foreach ($proc in $tartProcesses) {
        try {
            Stop-Process $proc -Force
            Write-Host "  Stopped process: $($proc.ProcessName) ($($proc.Id))"
        } catch {
            Write-Warning "  Could not stop process: $($proc.ProcessName)"
        }
    }

    # Clean temporary files
    Write-Host "Cleaning temporary files..."
    $tempDirs = @("/tmp/tart-*", "/var/tmp/tart-*")
    foreach ($dir in $tempDirs) {
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "✅ Environment cleaned"
}

# Main execution
try {
    switch ($Action) {
        "list" {
            Show-ImageList
        }
        "run" {
            Start-VM -ImageName $ImageName -ProjectPath $ProjectPath
        }
        "stop" {
            Stop-VM -ImageName $ImageName -All $All
        }
        "delete" {
            Remove-VM -ImageName $ImageName -All $All
        }
        "info" {
            Show-VMInfo -ImageName $ImageName
        }
        "ssh" {
            Connect-SSH -ImageName $ImageName
        }
        "clean" {
            Clean-Environment
        }
    }

} catch {
    Write-Error "❌ Action failed: $($_.Exception.Message)"
    exit 1
}