@{
    RootModule        = 'MauiProvisioning.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '9769c12a-6799-4824-b543-0b5f6ff81c37'
    Author            = 'maui-docker maintainers'
    CompanyName       = 'Community'
    Copyright         = 'Copyright (c) 2025'
    Description       = 'Cross-platform provisioning helpers to mirror .NET MAUI base image tooling on Windows, macOS, and Linux.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Invoke-MauiProvisioning')
    AliasesToExport   = @()
    CmdletsToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('maui', 'cross-platform', 'provisioning', 'dotnet')
            ProjectUri   = 'https://github.com/redth/maui-docker'
            LicenseUri   = 'https://github.com/redth/maui-docker/blob/main/LICENSE'
            ReleaseNotes = 'Refactored to support cross-platform provisioning (Windows, macOS, Linux).'
        }
    }
}
