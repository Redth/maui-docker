function Get-Platform {
    param()

    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return "Windows"
    } elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return "macOS"
    } elseif ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        return "Linux"
    } else {
        return "Unknown"
    }
}

function Test-IsWindows {
    return (Get-Platform) -eq "Windows"
}

function Test-IsMacOS {
    return (Get-Platform) -eq "macOS"
}

function Test-IsLinux {
    return (Get-Platform) -eq "Linux"
}