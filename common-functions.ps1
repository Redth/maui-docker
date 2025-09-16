# Common PowerShell functions for build scripts

# Function to compare semantic versions with prerelease support
function Compare-SemanticVersion {
    param (
        [string]$Version1,
        [string]$Version2,
        [bool]$Prefer1 = $true  # Return true if Version1 should be preferred over Version2
    )
    
    # Parse versions into components
    function Parse-SemanticVersion($version) {
        if ($version -match '^(\d+\.\d+\.\d+)(-(.+))?') {
            $baseVersion = $matches[1]
            $prerelease = $matches[3]
            
            # Parse prerelease components
            $prereleaseComponents = @()
            if ($prerelease) {
                $prereleaseComponents = $prerelease.Split('.')
            }
            
            return @{
                BaseVersion = [version]$baseVersion
                Prerelease = $prerelease
                PrereleaseComponents = $prereleaseComponents
                IsPrerelease = [bool]$prerelease
            }
        }
        throw "Invalid semantic version: $version"
    }
    
    try {
        $v1 = Parse-SemanticVersion $Version1
        $v2 = Parse-SemanticVersion $Version2
        
        # Compare base versions first
        if ($v1.BaseVersion -gt $v2.BaseVersion) {
            return $Prefer1
        } elseif ($v1.BaseVersion -lt $v2.BaseVersion) {
            return -not $Prefer1
        }
        
        # Base versions are equal, handle prerelease comparison
        if (-not $v1.IsPrerelease -and -not $v2.IsPrerelease) {
            return $false  # Both are release versions and equal
        } elseif (-not $v1.IsPrerelease -and $v2.IsPrerelease) {
            return $Prefer1  # v1 is release, v2 is prerelease - prefer release
        } elseif ($v1.IsPrerelease -and -not $v2.IsPrerelease) {
            return -not $Prefer1  # v1 is prerelease, v2 is release - prefer release
        }
        
        # Both are prerelease - compare prerelease identifiers
        # RC > preview > alpha/beta (RC should be preferred)
        function Get-PrereleaseRank($prerelease) {
            if ($prerelease -match '^rc') { return 3 }
            elseif ($prerelease -match '^preview') { return 2 }
            else { return 1 }  # alpha, beta, etc.
        }
        
        $rank1 = Get-PrereleaseRank $v1.Prerelease
        $rank2 = Get-PrereleaseRank $v2.Prerelease
        
        if ($rank1 -gt $rank2) {
            return $Prefer1
        } elseif ($rank1 -lt $rank2) {
            return -not $Prefer1
        }
        
        # Same rank - do lexical comparison of full prerelease string
        if ($v1.Prerelease -gt $v2.Prerelease) {
            return $Prefer1
        } elseif ($v1.Prerelease -lt $v2.Prerelease) {
            return -not $Prefer1
        }
        
        return $false  # Versions are identical
        
    } catch {
        Write-Warning "Error comparing versions $Version1 and $Version2`: $($_.Exception.Message)"
        return $false
    }
}

# Function to find the latest workload set version
function Find-LatestWorkloadSet {
    param (
        [string]$DotnetVersion,
        [string]$WorkloadSetVersion = "",
        [bool]$IncludePrerelease = $false,
        [bool]$AutoDetectPrerelease = $true
    )
    
    Write-Host "Finding latest workload set for .NET $DotnetVersion..."
    if ($WorkloadSetVersion) {
        Write-Host "Looking for specific workload set version: $WorkloadSetVersion"
    }
    
    # Extract major version (e.g., "9.0" from "9.0.100")
    $majorVersion = $DotnetVersion
    if ($DotnetVersion -match '^(\d+\.\d+)') {
        $majorVersion = $Matches[1]
    }
    
    # Auto-detect if prerelease is needed by first checking for stable versions
    $effectiveIncludePrerelease = $IncludePrerelease
    if ($AutoDetectPrerelease -and -not $WorkloadSetVersion) {
        Write-Host "Auto-detecting if prerelease versions are needed..."
        
        # First try to find stable versions
        $stableResponse = $null
        $searchPattern = "Microsoft.NET.Workloads.$majorVersion"
        
        try {
            # Try official search endpoint for stable versions
            $serviceIndex = Invoke-RestMethod -Uri "https://api.nuget.org/v3/index.json"
            $searchService = $serviceIndex.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' } | Select-Object -First 1
            
            if ($searchService) {
                $searchUrl = "$($searchService.'@id')?q=$searchPattern&prerelease=false&semVerLevel=2.0.0"
                $stableResponse = Invoke-RestMethod -Uri $searchUrl
            }
        }
        catch {
            # Fallback to direct search endpoint for stable versions
            $stableResponse = Invoke-RestMethod -Uri "https://azuresearch-usnc.nuget.org/query?q=$searchPattern&prerelease=false&semVerLevel=2.0.0"
        }
        
        # Filter stable workload sets (match SDK band pattern exactly)
        $stableWorkloadSets = $stableResponse.data | Where-Object { 
            # Match: Microsoft.NET.Workloads.{major}.{band} or Microsoft.NET.Workloads.{major}.{band}-{prerelease}
            # Allow prerelease identifiers with one dot (e.g., rc.1, preview.7) but exclude .Msi.{arch}
            $_.id -match "^Microsoft\.NET\.Workloads\.$majorVersion\.\d+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)?)*$"
        }
        
        if ($stableWorkloadSets -and $stableWorkloadSets.Count -gt 0) {
            Write-Host "Found $($stableWorkloadSets.Count) stable workload sets - using stable versions only"
            $effectiveIncludePrerelease = $false
        } else {
            Write-Host "No stable workload sets found - enabling prerelease search"
            $effectiveIncludePrerelease = $true
        }
    }
    
    if ($effectiveIncludePrerelease) {
        Write-Host "Including prerelease versions in search"
    } else {
        Write-Host "Using stable versions only"
    }
    
    # Search for workload set packages using the official NuGet API
    $searchPattern = "Microsoft.NET.Workloads.$majorVersion"
    
    try {
        # First, get the NuGet service index
        $serviceIndex = Invoke-RestMethod -Uri "https://api.nuget.org/v3/index.json"
        
        # Find the package search service
        $searchService = $serviceIndex.resources | Where-Object { $_.'@type' -eq 'SearchQueryService' } | Select-Object -First 1
        
        if (-not $searchService) {
            Write-Error "Could not find NuGet search service in the service index."
            return $null
        }
        
        # Use the official search endpoint
        $prereleaseParam = if ($effectiveIncludePrerelease) { "true" } else { "false" }
        $searchUrl = "$($searchService.'@id')?q=$searchPattern&prerelease=$prereleaseParam&semVerLevel=2.0.0"
        Write-Host "Using NuGet search URL: $searchUrl"
        
        $response = Invoke-RestMethod -Uri $searchUrl
    }
    catch {
        Write-Warning "Error accessing official NuGet API, falling back to direct search endpoint"
        # Fallback to the direct search endpoint if the service index approach fails
        $prereleaseParam = if ($effectiveIncludePrerelease) { "true" } else { "false" }
        $response = Invoke-RestMethod -Uri "https://azuresearch-usnc.nuget.org/query?q=$searchPattern&prerelease=$prereleaseParam&semVerLevel=2.0.0"
    }
    
    # Filter to match only SDK band workload sets (e.g., Microsoft.NET.Workloads.9.0.100 or Microsoft.NET.Workloads.10.0.100-rc.1)
    # This matches the exact SDK band pattern and excludes architecture-specific packages
    $workloadSets = $response.data | Where-Object { 
        # Match SDK band pattern: Microsoft.NET.Workloads.{major}.{band} or Microsoft.NET.Workloads.{major}.{band}-{prerelease}
        # Allow prerelease identifiers with one dot (e.g., rc.1, preview.7) but exclude .Msi.{arch}
        $_.id -match "^Microsoft\.NET\.Workloads\.$majorVersion\.\d+(-[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)?)*$"
    }
    
    # If a specific WorkloadSetVersion is provided, filter to only that version
    if ($WorkloadSetVersion) {
        $workloadSets = $workloadSets | Where-Object { $_.version -eq $WorkloadSetVersion }
        if (-not $workloadSets) {
            Write-Error "No workload set found for .NET $majorVersion with version $WorkloadSetVersion"
            return $null
        }
        # If we found a specific version, return it directly
        if ($workloadSets.Count -eq 1) {
            $foundWorkloadSet = $workloadSets[0]
            Write-Host "Found specific workload set: $($foundWorkloadSet.id) v$($foundWorkloadSet.version)"
            Write-Host "DEBUG: Package ID that will be used: $($foundWorkloadSet.id)"
            return $foundWorkloadSet
        } elseif ($workloadSets.Count -gt 1) {
            # Multiple workload sets with the same version (different bands), pick the highest band
            Write-Host "Found multiple workload sets with version $WorkloadSetVersion, selecting highest band..."
        }
    }
    
    if (-not $workloadSets) {
        Write-Error "No workload sets found for .NET $majorVersion"
        return $null
    }
    
    # Group by version band (e.g., 9.0.100, 9.0.200) and find the latest version in each band
    $versionBands = @{}
    
    foreach ($ws in $workloadSets) {
        # Extract base version band (e.g., "10.0.100" from "10.0.100-rc.1" or "10.0.100-preview.6")
        $fullBand = $ws.id -replace "Microsoft\.NET\.Workloads\.", ""
        $versionBand = $fullBand
        if ($fullBand -match '^(\d+\.\d+\.\d+)(-.*)?') {
            $versionBand = $matches[1]
        }
        
        if (-not $versionBands.ContainsKey($versionBand)) {
            $versionBands[$versionBand] = $ws
        } else {
            # Compare semantic versions properly (handles prerelease identifiers)
            if (Compare-SemanticVersion -Version1 $ws.version -Version2 $versionBands[$versionBand].version -Prefer1 $true) {
                $versionBands[$versionBand] = $ws
            }
        }
    }
    
    # Find the highest version band by parsing the band number
    $highestBand = $versionBands.Keys | ForEach-Object {
        # Extract the band part (e.g., "100" from "9.0.100" or "10.0.100-rc.1")
        if ($_ -match "$majorVersion\.(\d+)") {
            [PSCustomObject]@{
                FullBand = $_
                BandNumber = [int]$Matches[1]
            }
        }
    } | Sort-Object -Property BandNumber -Descending | Select-Object -First 1 -ExpandProperty FullBand
    
    if ($highestBand) {
        $latestWorkloadSet = $versionBands[$highestBand]
        Write-Host "Found latest workload set: $($latestWorkloadSet.id) v$($latestWorkloadSet.version)"
        Write-Host "DEBUG: Package ID that will be used: $($latestWorkloadSet.id)"
        return $latestWorkloadSet
    }
    
    Write-Error "Failed to determine the latest workload set version"
    return $null
}

# Function to download and extract a NuGet package
function Get-NuGetPackageContent {
    param (
        [string]$PackageId,
        [string]$Version,
        [string]$FilePath
    )
    
    $envTemp = $env:TEMP
    if (-not $envTemp) {
        $envTemp = "./_temp"
    }

    $tempDir = Join-Path $envTemp "nuget_extract_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    $nupkgPath = Join-Path $tempDir "$PackageId.$Version.nupkg"
    $extractPath = Join-Path $tempDir "extracted"
    
    try {
        # Download the package
        $nugetUrl = "https://www.nuget.org/api/v2/package/$PackageId/$Version"
        Write-Host "Downloading $PackageId v$Version..."
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nupkgPath
        
        # Extract the package (nupkg files are zip files)
        Expand-Archive -Path $nupkgPath -DestinationPath $extractPath -Force
        
        # Check if the requested file exists
        $targetFile = Join-Path $extractPath $FilePath
        Write-Host "Looking for file: $targetFile"
        if (Test-Path $targetFile) {
            $content = Get-Content -Path $targetFile -Raw
            return $content
        } else {
            Write-Error "File '$FilePath' not found in package $PackageId v$Version"
            return $null
        }
    }
    catch {
        Write-Error "Error processing NuGet package $PackageId v${Version}: $_"
        return $null
    }
    finally {
        # Clean up
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}

# Function to convert NuGet-compatible version to dotnet workload CLI version format
function Convert-ToWorkloadVersion {
    param (
        [string]$NuGetVersion
    )
    
    if ([string]::IsNullOrEmpty($NuGetVersion)) {
        return $null
    }
    
    Write-Host "Converting NuGet version '$NuGetVersion' to dotnet workload CLI format"
    
    # Split the version by dots
    $parts = $NuGetVersion.Split('.')
    
    # NuGet versions are typically in format like 9.203.0 or 9.203.1
    # Dotnet CLI expects format like 9.0.203 or 9.0.203.1
    if ($parts.Count -ge 3) {
        $major = $parts[0]
        $minor = "0"  # Always 0 in dotnet CLI format for the second component
        $patch = $parts[1]  # The third component in CLI format is from the second in NuGet
        
        # Start building the dotnet CLI version
        $workloadVersion = "$major.$minor.$patch"
        
        # If there are additional components, add them to the end
        if ($parts.Count -gt 3) {
            for ($i = 2; $i -lt $parts.Count; $i++) {
                $workloadVersion += ".$($parts[$i])"
            }
        }
        # If we have exactly 3 parts and the last one is not 0, add it
        elseif ($parts[2] -ne "0") {
            $workloadVersion += ".$($parts[2])"
        }
        
        Write-Host "Converted to: $workloadVersion"
        return $workloadVersion
    }
    
    # If the format doesn't match our expectations, return the original version
    Write-Host "Could not convert version, using original: $NuGetVersion"
    return $NuGetVersion
}

# Parse the version information (format is "version/sdk-band")
function Parse-VersionInfo {
    param (
        [string]$VersionString,
        [string]$WorkloadName
    )
    
    if ($VersionString -match '(.+)/(.+)') {
        $Version = $Matches[1]
        $SdkBand = $Matches[2]
        
        return @{
            Version = $Version
            SdkBand = $SdkBand
        }
    } else {
        Write-Error "Failed to parse version information for ${WorkloadName} : $VersionString"
        return $null
    }
}

# Function to extract Android SDK and JDK information from workload dependencies
function Get-AndroidWorkloadInfo {
    param (
        [PSObject]$Dependencies,
        [string]$DockerPlatform
    )
    
    # Initialize variables to store extracted information
    $androidJdkRecommendedVersion = $null
    $androidJdkVersionRange = $null
    $androidJdkMajorVersion = $null
    $androidSdkPackages = @()
    $buildToolsVersion = $null
    $cmdLineToolsVersion = $null
    $apiLevel = $null
    $systemImageType = $null
    $avdDeviceType = $null
    $systemImageArch = $null
    
    if ($DockerPlatform.StartsWith("linux/")) {
        $targetPlatform = "linux-x54"
    } elseif ($DockerPlatform.StartsWith("windows/")) {
        $targetPlatform = "win-x64"
    } else {
        Write-Error "Unsupported Docker platform: $DockerPlatform"
        return $null
    }
    Write-Host "Target platform: $targetPlatform"
    
    # Extract Android SDK information from the proper structure
    $androidInfo = $Dependencies."microsoft.net.sdk.android"
    if ($androidInfo) {
        # Extract JDK information
        if ($androidInfo.jdk) {
            $androidJdkVersionRange = $androidInfo.jdk.version
            $androidJdkRecommendedVersion = $androidInfo.jdk.recommendedVersion
            
            Write-Host "Found Android JDK info:"
            Write-Host "  Version Range: $androidJdkVersionRange"
            Write-Host "  Recommended Version: $androidJdkRecommendedVersion"
            
            # Extract major version from recommended version
            if ($androidJdkRecommendedVersion -match '^(\d+)') {
                $androidJdkMajorVersion = $Matches[1]
                Write-Host "  Extracted JDK major version: $androidJdkMajorVersion"
            }
        }
        
        # Extract Android SDK packages
        if ($androidInfo.androidsdk -and $androidInfo.androidsdk.packages) {
            $packages = $androidInfo.androidsdk.packages
            
            foreach ($package in $packages) {
                $desc = $package.desc
                $optional = [bool]::Parse($package.optional)
                
                # Get the package ID (handling platform-specific IDs)
                $packageId = $null
                if ($package.sdkPackage.id -is [string]) {
                    $packageId = $package.sdkPackage.id
                } elseif ($package.sdkPackage.id.$targetPlatform) {
                    $packageId = $package.sdkPackage.id.$targetPlatform
                }
                
                # Get recommended version if available
                $recommendedVersion = $package.sdkPackage.recommendedVersion
                
                # Create a structured object with detailed package info
                if ($packageId) {
                    $packageInfo = [PSCustomObject]@{
                        Id = $packageId
                        Description = $desc
                        Optional = $optional
                        RecommendedVersion = $recommendedVersion
                    }
                    
                    $androidSdkPackages += $packageInfo
                    
                    Write-Host "Found Android SDK package: $($packageId) ($(if($optional){'Optional'}else{'Required'}))"
                }
            }
        }
    }
    
    # Output summary of found packages
    Write-Host "Found $($androidSdkPackages.Count) Android SDK packages"
    
    # Extract key information for Docker build arguments
    $buildToolsPackage = $androidSdkPackages | Where-Object { $_.Id -match "^build-tools;" } | Select-Object -First 1
    $cmdLineToolsPackage = $androidSdkPackages | Where-Object { $_.Id -match "^cmdline-tools;" } | Select-Object -First 1
    $platformPackage = $androidSdkPackages | Where-Object { $_.Id -match "^platforms;android-" } | Select-Object -First 1
    
    # Find the best system image package based on platform and preference for Google APIs
    $systemImagePackages = $androidSdkPackages | Where-Object { $_.Id -match "^system-images;" }
    $systemImagePackage = $systemImagePackages | Select-Object -First 1

    # Log the selected system image package
    if ($systemImagePackage) {
        Write-Host "Selected system image package: $($systemImagePackage.Id)"
    } else {
        Write-Warning "No system image package found"
    }
    
    # Extract specific versions from package IDs
    if ($buildToolsPackage -and $buildToolsPackage.Id -match 'build-tools;(\d+\.\d+\.\d+)') {
        $buildToolsVersion = $Matches[1]
    }
    
    if ($cmdLineToolsPackage -and $cmdLineToolsPackage.Id -match 'cmdline-tools;(\d+\.\d+)') {
        $cmdLineToolsVersion = $Matches[1]
    }
    
    if ($platformPackage -and $platformPackage.Id -match 'platforms;android-(\d+)') {
        $apiLevel = $Matches[1]
    }
    
    # Extract system image type and device type information
    if ($systemImagePackage) {
        # Extract system image type (e.g., google_apis, google_apis_playstore)
        if ($systemImagePackage.Id -match 'system-images;android-\d+;([^;]+);([^;]+)') {
            $systemImageType = $Matches[1]
            $systemImageArch = $Matches[2]
            Write-Host "Selected system image type: $systemImageType, architecture: $systemImageArch"
        }
        
        $avdDeviceType = "nexus_5" # Default device type
        
        Write-Host "Selected AVD device type: $avdDeviceType"
    }
    
    # Return the collected information
    return @{
        JdkMajorVersion = $androidJdkMajorVersion
        JdkRecommendedVersion = $androidJdkRecommendedVersion
        JdkVersionRange = $androidJdkVersionRange
        BuildToolsVersion = $buildToolsVersion
        CmdLineToolsVersion = $cmdLineToolsVersion
        ApiLevel = $apiLevel
        SystemImageType = $systemImageType
        AvdDeviceType = $avdDeviceType
        AvdSystemImageArch = $systemImageArch
        SystemImagePackage = $systemImagePackage
        Packages = $androidSdkPackages
    }
}

# Function to get workload set information including versions and dependencies
function Get-WorkloadSetInfo {
    param (
        [string]$DotnetVersion,
        [string]$WorkloadSetVersion = "",
        [string[]]$WorkloadNames = @("Microsoft.NET.Sdk.Android"),
        [bool]$IncludePrerelease = $false
    )
    
    # Extract major version (e.g., "9.0" from "9.0.100") for package ID construction
    $majorVersion = $DotnetVersion
    if ($DotnetVersion -match '^(\d+\.\d+)') {
        $majorVersion = $Matches[1]
    }
    
    # Find the latest workload set if not specified
    if (-not $WorkloadSetVersion) {
        $latestWorkloadSet = Find-LatestWorkloadSet -DotnetVersion $majorVersion -IncludePrerelease $IncludePrerelease -AutoDetectPrerelease $true
        if ($latestWorkloadSet) {
            $WorkloadSetVersion = $latestWorkloadSet.version
            $WorkloadSetId = $latestWorkloadSet.id  # Use the actual package ID from search results
            Write-Host "Using workload set: $WorkloadSetId v$WorkloadSetVersion"
        } else {
            Write-Error "Failed to find a valid workload set. Please specify WorkloadSetVersion manually."
            return $null
        }
    } else {
        # Find the workload set with the specified version
        $specificWorkloadSet = Find-LatestWorkloadSet -DotnetVersion $majorVersion -WorkloadSetVersion $WorkloadSetVersion -IncludePrerelease $IncludePrerelease -AutoDetectPrerelease $true
        if ($specificWorkloadSet) {
            $WorkloadSetId = $specificWorkloadSet.id  # Use the actual package ID from search results
            Write-Host "Using specified workload set: $WorkloadSetId v$WorkloadSetVersion"
        } else {
            Write-Error "Failed to find workload set with version $WorkloadSetVersion for .NET $majorVersion"
            return $null
        }
    }

    # Convert the WorkloadSetVersion to the format expected by dotnet workload CLI commands
    $DotnetCommandWorkloadSetVersion = Convert-ToWorkloadVersion -NuGetVersion $WorkloadSetVersion
    Write-Host "Using dotnet workload CLI version: $DotnetCommandWorkloadSetVersion"

    # Download and parse the workload set JSON
    $workloadSetJsonContent = Get-NuGetPackageContent -PackageId $WorkloadSetId -Version $WorkloadSetVersion -FilePath "data/microsoft.net.workloads.workloadset.json"
    $workloadSetData = $workloadSetJsonContent | ConvertFrom-Json

    Write-Host "Parsing workload information from workload set..."

    # Create result object
    $result = @{
        DotnetVersion = $DotnetVersion
        WorkloadSetId = $WorkloadSetId
        WorkloadSetVersion = $WorkloadSetVersion
        DotnetCommandWorkloadSetVersion = $DotnetCommandWorkloadSetVersion
        Workloads = @{}
    }

    # Process each requested workload
    foreach ($workloadName in $WorkloadNames) {
        $versionInfo = $workloadSetData.$workloadName
        
        # Check if we found the workload
        if (-not $versionInfo) {
            Write-Warning "Could not find workload '$workloadName' in the workload set."
            continue
        }

        # Parse version information
        $info = Parse-VersionInfo -VersionString $versionInfo -WorkloadName $workloadName
        if (-not $info) {
            Write-Warning "Failed to parse version information for $workloadName"
            continue
        }

        $version = $info.Version
        $sdkBand = $info.SdkBand

        Write-Host "Found workload '$workloadName': version=$version, sdk-band=$sdkBand"

        # Build manifest ID
        $manifestId = "$workloadName.Manifest-$sdkBand"

        # Get the manifest content
        $manifestContent = Get-NuGetPackageContent -PackageId $manifestId -Version $version -FilePath "data/WorkloadManifest.json"

        # Get the dependencies content
        $dependenciesContent = Get-NuGetPackageContent -PackageId $manifestId -Version $version -FilePath "data/WorkloadDependencies.json"

        # Parse the dependencies into objects
        $dependencies = $dependenciesContent | ConvertFrom-Json

        # Add to result
        $result.Workloads[$workloadName] = @{
            Id = $workloadName
            Version = $version
            SdkBand = $sdkBand
            ManifestId = $manifestId
            Dependencies = $dependencies
        }
    }

    return $result
}

# Comprehensive function to get all workload information in one call
function Get-WorkloadInfo {
    param (
        [string]$DotnetVersion,
        [string]$WorkloadSetVersion = "",
        [switch]$IncludeAndroid,
        [switch]$IncludeiOS,
        [switch]$IncludeMaui,
        [string]$DockerPlatform
    )
    
    # Determine which workloads to include
    $workloadNames = @()
    if ($IncludeAndroid) {
        $workloadNames += "Microsoft.NET.Sdk.Android"
    }
    if ($IncludeiOS) {
        $workloadNames += "Microsoft.NET.Sdk.iOS"
    }
    if ($IncludeMaui) {
        $workloadNames += "Microsoft.NET.Sdk.Maui"
    }
    
    # If no specific workloads selected, include all supported ones
    if ($workloadNames.Count -eq 0) {
        $workloadNames = @("Microsoft.NET.Sdk.Android", "Microsoft.NET.Sdk.iOS", "Microsoft.NET.Sdk.Maui")
        Write-Host "No specific workloads selected, including all supported workloads."
    }
    
    Write-Host "Getting workload information for: $($workloadNames -join ', ')"
    
    # Get the basic workload set information
    $workloadSetInfo = Get-WorkloadSetInfo -DotnetVersion $DotnetVersion -WorkloadSetVersion $WorkloadSetVersion -WorkloadNames $workloadNames
    
    if (-not $workloadSetInfo) {
        Write-Error "Failed to get workload set information."
        return $null
    }
    
    # Create the result object
    $result = @{
        DotnetVersion = $workloadSetInfo.DotnetVersion
        WorkloadSetId = $workloadSetInfo.WorkloadSetId
        WorkloadSetVersion = $workloadSetInfo.WorkloadSetVersion
        DotnetCommandWorkloadSetVersion = $workloadSetInfo.DotnetCommandWorkloadSetVersion
        Workloads = @{}
    }
    
    # Process each workload to get detailed dependency information
    foreach ($workloadName in $workloadNames) {
        $workload = $workloadSetInfo.Workloads[$workloadName]
        
        if (-not $workload) {
            Write-Warning "Workload '$workloadName' not found in workload set, skipping."
            continue
        }
        
        Write-Host "Processing dependency information for $workloadName"
        
        # Create a workload entry with basic info
        $workloadResult = @{
            Id = $workload.Id
            Version = $workload.Version
            SdkBand = $workload.SdkBand
            ManifestId = $workload.ManifestId
            Dependencies = $workload.Dependencies
        }
        
        # Get specific information based on the workload type
        switch ($workloadName) {
            "Microsoft.NET.Sdk.Android" {
                if ($IncludeAndroid) {
                    $androidInfo = Get-AndroidWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    $workloadResult.Details = $androidInfo
                }
            }
            "Microsoft.NET.Sdk.iOS" {
                if ($IncludeiOS) {
                    # For future implementation - iOS-specific info parser
                    # $iOSInfo = Get-iOSWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    # $workloadResult.Details = $iOSInfo
                }
            }
            "Microsoft.NET.Sdk.Maui" {
                if ($IncludeMaui) {
                    # For future implementation - MAUI-specific info parser
                    # $mauiInfo = Get-MauiWorkloadInfo -Dependencies $workload.Dependencies -DockerPlatform $DockerPlatform
                    # $workloadResult.Details = $mauiInfo
                }
            }
        }
        
        # Add the workload to the result
        $result.Workloads[$workloadName] = $workloadResult
    }
    
    return $result
}

# Function to get the latest version of an npm package
function Get-LatestNpmPackageVersion {
    param (
        [string]$PackageName
    )
    
    Write-Host "Getting latest version for npm package: $PackageName"
    
    try {
        # Use npm registry API to get package information
        $registryUrl = "https://registry.npmjs.org/$PackageName"
        $response = Invoke-RestMethod -Uri $registryUrl -Headers @{ "Accept" = "application/json" }
        
        # Get the latest version from the dist-tags
        $latestVersion = $response.'dist-tags'.latest
        
        if ($latestVersion) {
            Write-Host "Latest version of ${PackageName}: $latestVersion"
            return $latestVersion
        } else {
            Write-Warning "Could not find latest version for package: $PackageName"
            return $null
        }
    }
    catch {
        Write-Warning "Error getting npm package version for ${PackageName}: $($_.Exception.Message)"
        return $null
    }
}

# Function to get latest Appium-related package versions
function Get-LatestAppiumVersions {
    Write-Host "Getting latest Appium package versions from npm..."
    
    $appiumVersion = Get-LatestNpmPackageVersion -PackageName "appium"
    $uiAutomator2Version = Get-LatestNpmPackageVersion -PackageName "appium-uiautomator2-driver"
    
    return @{
        AppiumVersion = $appiumVersion
        UIAutomator2DriverVersion = $uiAutomator2Version
    }
}

#Get-NuGetPackageContent -PackageId 'Microsoft.NET.Workloads.9.0.300' -Version '9.301.1' -FilePath 'data/WorkloadManifest.json' 
