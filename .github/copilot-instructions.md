# .NET MAUI Docker Repository - Copilot Instructions

## Repository Overview

This repository provides Docker images for .NET MAUI development across three main categories:
1. **Base Images** (`base/`) - MAUI development environment without GitHub Actions runner
2. **Runner Images** (`runner/`) - Base images + GitHub Actions runner for CI/CD 
3. **Test Images** (`test/`) - Ready-to-use testing environment with Appium and Android Emulator

**Repository Size**: Small (~50 files)  
**Languages**: PowerShell (primary), Dockerfile, YAML  
**Platforms**: Linux (amd64), Windows (amd64)  
**Target Runtimes**: .NET 9.0, Docker containers  
**Published Images**: Docker Hub (`redth/maui-build`, `redth/maui-actions-runner`, `redth/maui-testing`)

## Build Instructions - CRITICAL REQUIREMENTS

### Prerequisites
- **Docker**: Required for all builds
- **PowerShell 7+**: All build scripts use PowerShell Core
- **Internet access**: Scripts download workload versions from NuGet and npm APIs

### Key Commands That ALWAYS Work

**ALWAYS run PowerShell scripts from the repository root:**
```bash
cd /path/to/maui-docker
pwsh ./script-name.ps1 [parameters]
```

**Test PowerShell Functions (Validates Environment):**
```bash
pwsh -Command ". ./common-functions.ps1; Get-LatestAppiumVersions"
pwsh -Command ". ./common-functions.ps1; Find-LatestWorkloadSet -DotnetVersion '9.0'"
```

**Build Base Images (Linux - Works in Docker environments):**
```bash
pwsh ./base/base-build.ps1 -DotnetVersion "9.0" -DockerPlatform "linux/amd64" -DockerRepository "test/maui-build" -Load:$true
```

**Build Test Images (Requires base image first):**
```bash
pwsh ./test/build.ps1 -AndroidSdkApiLevel 35 -DockerRepository "test/maui-testing" -Load:$true
```

### Build Sequence - MUST Follow Order
1. **Base images** must be built before runner/test images
2. **Windows builds** require Windows runners in CI
3. **Test images** are Linux-only and require `/dev/kvm` device for emulator

### Common Build Failures & Solutions

**PowerShell Boolean Parameters:**
- Use `-Load:$true` or `-Push:$false` syntax for boolean parameters
- Incorrect: `-Load $true` - Correct: `-Load:$true`

**Network Dependencies:**
- Workload detection requires internet access to NuGet and npm APIs
- In isolated environments, builds may fail during workload detection phase
- Scripts include fallback versions when API calls fail

**Docker Build Context Issues:**
- All Docker builds use platform-specific subdirectories (`base/linux/`, `base/windows/`)
- Build scripts automatically change to correct directory

**Workload Set Detection Failures:**
- Internet access required for NuGet API calls
- Scripts have fallback versions if APIs fail
- Timeouts normal for first workload detection (can take 2-3 minutes)

## Project Layout & Architecture

### Core Directories
```
.github/workflows/     # CI/CD - builds triggered by schedule or dispatch
base/                  # Base development images (foundation)
├── base-build.ps1     # Cross-platform base image builder
├── linux/             # Linux-specific Dockerfile and scripts
└── windows/           # Windows-specific Dockerfile and scripts
runner/                # GitHub Actions runner images (extends base)
├── runner-build.ps1   # Cross-platform runner builder  
├── linux/             # Linux runner implementation
└── windows/           # Windows runner implementation
test/                  # Testing images with Appium + Android emulator
├── build.ps1          # Test image builder (Linux only)
├── run.ps1            # Container runner helper
└── Dockerfile         # Test image definition
common-functions.ps1   # CRITICAL: Shared PowerShell functions
check-workload-updates.ps1  # Automated version checking
```

### Configuration Files
- **GitHub Workflows**: `.github/workflows/*.yml` - Complex matrix builds
- **Docker**: `*/Dockerfile` - Multi-stage, parameterized builds
- **VSCode**: `.vscode/launch.json` - PowerShell debugging setup

### Dependencies & Architecture
**Image Hierarchy:**
```
Microsoft .NET SDK Image
    ↓
Base Image (MAUI Dev Environment)
    ↓
Runner Image (Base + GitHub Actions)    Test Image (Base + Appium/Emulator)
```

**External Dependencies:**
- NuGet API for .NET workload versions
- npm registry for Appium versions  
- Docker Hub for base Microsoft images
- Android SDK packages (dynamically determined)

### GitHub Workflows - Validation Pipeline

**Primary Workflows:**
- `build-all.yml` - Comprehensive build of all image types
- `build-base.yml` - Base images only  
- `build-runner.yml` - Runner images only
- `build-test.yml` - Test images only
- `check-workload-updates.yml` - Automated version monitoring

**Critical Workflow Features:**
- Matrix builds across .NET versions and Android API levels
- Automatic workload version detection
- Multi-platform support (Linux/Windows)
- Dependency ordering (base → runner/test)

### Key Source Files

**common-functions.ps1** (Most Important):
- `Find-LatestWorkloadSet()` - Gets latest .NET workload versions
- `Get-WorkloadInfo()` - Comprehensive workload dependency analysis
- `Get-AndroidWorkloadInfo()` - Android SDK requirements extraction
- `Get-LatestAppiumVersions()` - npm package version detection

**Build Entry Points:**
- `base/base-build.ps1` - Main base image builder
- `runner/runner-build.ps1` - Runner image builder
- `test/build.ps1` - Test image builder

## Validation Steps for Changes

**Before Making Changes:**
1. Test PowerShell functions: `pwsh -Command ". ./common-functions.ps1; Find-LatestWorkloadSet -DotnetVersion '9.0'"`
2. Verify Docker: `docker --version`
3. Check workflow syntax: GitHub Actions validates on push

**After Making Changes:**  
1. **ALWAYS test build scripts locally** before committing
2. For Dockerfile changes: Build locally with `-Load $true`
3. For PowerShell changes: Test functions individually
4. For workflow changes: Use workflow_dispatch to test

**Trust These Instructions:** The build processes are complex with dynamic version detection. Only search for additional information if these instructions are incomplete or incorrect.