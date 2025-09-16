# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository builds Docker images for .NET MAUI development, testing, and CI/CD. It provides three main types of Docker images:

1. **Base Images** (`base/`) - MAUI development environment without GitHub Actions runner
2. **Runner Images** (`runner/`) - Base images + GitHub Actions runner for CI/CD  
3. **Test Images** (`test/`) - Ready-to-use testing environment with Appium and Android Emulator

## Build Commands

### Building Base Images
```powershell
# Linux base image
./base/linux/build.ps1 -DotnetVersion "9.0" -DockerRepository "your-repo/maui-build" -Version "latest"
./base/linux/build.ps1 -DotnetVersion "10.0" -DockerRepository "your-repo/maui-build" -Version "latest"

# Windows base image  
./base/windows/build.ps1 -DotnetVersion "9.0" -DockerRepository "your-repo/maui-build" -Version "latest"
./base/windows/build.ps1 -DotnetVersion "10.0" -DockerRepository "your-repo/maui-build" -Version "latest"

# Both platforms using unified script
./base/base-build.ps1 -DockerPlatform "linux/amd64" -DockerRepository "your-repo/maui-build"
./base/base-build.ps1 -DockerPlatform "windows/amd64" -DockerRepository "your-repo/maui-build"
```

### Building Runner Images
```powershell
# Build runner images (depend on base images)
./runner/runner-build.ps1 -DotnetVersion "9.0" -DockerRepository "your-repo/maui-actions-runner" -DockerPlatform "linux/amd64"
./runner/runner-build.ps1 -DotnetVersion "10.0" -DockerRepository "your-repo/maui-actions-runner" -DockerPlatform "linux/amd64"
./runner/runner-build.ps1 -DotnetVersion "9.0" -DockerRepository "your-repo/maui-actions-runner" -DockerPlatform "windows/amd64"
./runner/runner-build.ps1 -DotnetVersion "10.0" -DockerRepository "your-repo/maui-actions-runner" -DockerPlatform "windows/amd64"
```

### Building Test Images
```powershell
# Build test images with specific Android API level
./test/build.ps1 -DotnetVersion "9.0" -AndroidSdkApiLevel 35 -DockerRepository "your-repo/maui-testing"
./test/build.ps1 -DotnetVersion "10.0" -AndroidSdkApiLevel 35 -DockerRepository "your-repo/maui-testing"

# Run a test container
./test/run.ps1 -AndroidSdkApiLevel 35
```

### Checking for Workload Updates
```powershell
# Check for .NET workload updates
./check-workload-updates.ps1 -DotnetVersion "9.0"
./check-workload-updates.ps1 -DotnetVersion "10.0"
```

## Architecture and Key Components

### Workload Management System
The repository uses a sophisticated workload management system (`common-functions.ps1`) that:
- Automatically discovers the latest .NET workload sets from NuGet
- **Auto-detects** when prerelease versions are needed (when no stable versions exist)
- Extracts Android SDK requirements, Java versions, and API levels from workload manifests
- Converts between NuGet package versions and dotnet CLI workload versions
- Downloads and parses workload dependency information

**Smart Prerelease Detection**: The system first searches for stable workload sets using precise SDK band pattern matching. If none are found (like with .NET 10), it automatically enables prerelease search. This ensures:
- .NET 9: Always uses stable versions (9.305.0)
- .NET 10: Automatically uses prerelease versions (RC1, previews, etc.)
- Future versions: Automatically adapts when stable versions become available

**Precise Package Filtering**: Uses SDK band pattern matching (`Microsoft.NET.Workloads.{major}.{band}(-{prerelease})?`) to correctly identify workload sets while excluding architecture-specific packages like `.Msi.x64`.

Key functions:
- `Find-LatestWorkloadSet` - Finds latest workload set with intelligent prerelease auto-detection
- `Get-WorkloadSetInfo` - Gets complete workload set information
- `Get-AndroidWorkloadInfo` - Extracts Android-specific requirements
- `Get-LatestAppiumVersions` - Gets latest Appium versions from npm

### Docker Image Hierarchy
```
Base Image (MAUI Dev Environment)
    ↓
Runner Image (Base + GitHub Actions Runner)
    ↓  
Test Image (Runner + Appium + Android Emulator)
```

### Platform Support
- **Linux**: `linux/amd64` - Full support for all image types
- **Windows**: `windows/amd64` - Base and Runner images only (Test images Linux-only)

### .NET Version Support
- **.NET 8**: Stable release workloads (8.414.0)
- **.NET 9**: Stable release workloads (9.305.0) 
- **.NET 10**: Prerelease workloads (RC1, previews) - automatically detected
- **Future versions**: Auto-adapts when stable versions become available

### Android API Level Management
The build system:
- Automatically detects required API levels from workload dependencies
- Supports building images for API levels 23-35
- Uses workload-recommended API levels by default but allows overrides

### GitHub Actions Integration
Comprehensive CI/CD workflows in `.github/workflows/`:
- `build-all.yml` - Builds all image types with matrix strategy
- `build-base.yml` - Builds base images only
- `build-runner.yml` - Builds runner images only  
- `build-test.yml` - Builds test images for multiple API levels
- `check-workload-updates.yml` - Monitors for workload updates

## Common Parameters

Most build scripts accept these common parameters:
- `DotnetVersion` - .NET version (e.g., "9.0")
- `WorkloadSetVersion` - Specific workload set version (optional, auto-detected if not specified)
- `DockerRepository` - Docker repository name
- `DockerPlatform` - Target platform (linux/amd64 or windows/amd64)
- `Version` - Docker tag version
- `Push` - Whether to push to registry
- `Load` - Whether to load image locally

## Development Workflow

1. Make changes to Dockerfiles or build scripts
2. Test locally using individual build scripts
3. **PR Validation**: Automatic build testing on pull requests (no publishing)
4. Use GitHub Actions workflows for full CI/CD pipeline
5. All builds use the workload management system to ensure consistent versions

### PR Testing
The repository includes a dedicated PR validation workflow (`pr-validation.yml`) that:
- Automatically runs on PRs targeting main branch
- Tests Docker image builds without publishing
- Validates workload discovery for all .NET versions
- Provides three test modes: `single-platform`, `base-only`, or `all`
- See `.github/PR-VALIDATION.md` for detailed usage guide

## Key Environment Variables

For runner images:
- `GITHUB_TOKEN` - Required for runner registration
- `GITHUB_ORG` - GitHub organization 
- `GITHUB_REPO` - Repository name (optional, defaults to org-level)
- `RUNNER_NAME` - Custom runner name
- `INIT_PWSH_SCRIPT` - Custom PowerShell initialization script
- `INIT_BASH_SCRIPT` - Custom bash initialization script (Linux only)

For test images:
- Android emulator and Appium are pre-configured and auto-started
- Requires `--device /dev/kvm` for nested virtualization
- Maps ports 5554, 5555 (emulator/ADB) and 4723 (Appium)

## Testing

The test images are designed for UI testing with Appium and include:
- Pre-installed Android Emulator for specified API level
- Appium Server with UIAutomator2 driver
- Automatic service startup on container launch
- Support for mapping APK volumes for testing