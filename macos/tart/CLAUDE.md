# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This directory contains Tart VM (Cirrus Labs Tart) infrastructure for building macOS VM images optimized for .NET MAUI development and CI/CD workflows. Tart provides Docker-like virtualization for macOS environments.

## Build Commands

### Building VM Images
```powershell
# Build MAUI development image (default: Sequoia + .NET 10.0)
pwsh ./scripts/build.ps1 -ImageType maui -MacOSVersion sequoia -DotnetChannel 10.0

# Build with specific Xcode version
pwsh ./scripts/build.ps1 -ImageType maui -MacOSVersion tahoe -DotnetChannel 10.0 -XcodeVersion 26

# Quick start with all prerequisites check and build
pwsh ./scripts/quick-start.ps1 -BuildType maui -MacOSVersion sequoia -DotnetChannel 10.0
```

### Testing Images
```powershell
# Test built image
pwsh ./scripts/test.ps1 -ImageName maui-dev-sequoia -TestType maui
```

### Runner Auto-registration
```powershell
$env:GITHUB_ORG = 'your-org'
$env:GITHUB_TOKEN = 'ghp_xxx'
tart run maui-dev-sequoia
```

### VM Management
```bash
# Run VM with project directory mounted
tart run maui-dev-sequoia --dir project:/path/to/your/project

# List VMs and get IP for SSH access
tart list
tart ip maui-dev-sequoia

# SSH into running VM
ssh admin@$(tart ip maui-dev-sequoia)
```

## Architecture

### Image Hierarchy
```
Cirrus Labs Base macOS Image (macos-sequoia-xcode:16.4)
    ↓
MAUI Development Image (maui.pkr.hcl)
    - .NET SDK + MAUI workloads
    - Xcode tooling + iOS simulators
    - Android SDK + development tools
    - VS Code + development utilities
    - GitHub runner helper script (auto-registration via env vars)
```

### Configuration System

**Platform Matrix (`config/platform-matrix.json`)**:
- Defines macOS versions (sequoia, tahoe) and their Xcode compatibility
- Maps .NET channels to supported macOS/Xcode combinations
- Used by build script for automatic version resolution

**Variables (`config/variables.json`)**:
- Shared resource defaults (CPU, memory, disk size)
- Tool installation flags
- VM optimization settings
- Consumed by Packer templates

### Key Components

1. **Packer Templates** (`templates/`):
   - `maui.pkr.hcl`: Base MAUI development environment with optional GitHub runner bootstrap

2. **Build Scripts** (`scripts/`):
   - `build.ps1`: Main build orchestration with platform matrix resolution
   - `quick-start.ps1`: Automated setup with prerequisite checking
   - `test.ps1`: Image validation and testing
   - `manage.ps1`: VM lifecycle management

3. **Configuration** (`config/`):
   - Platform matrix for version compatibility
   - Shared variables and optimization settings

### Version Resolution Logic

The build system automatically resolves compatible versions:
- If `-XcodeVersion` not specified, uses `RecommendedXcodeVersion` from platform matrix
- Validates macOS/Xcode/.NET channel compatibility
- Supports both stable (.NET 9.0) and preview (.NET 10.0) channels
- Uses Tahoe (macOS 16) + Xcode 26 for bleeding-edge development

### Base Images

Uses Cirrus Labs public base images:
- `ghcr.io/cirruslabs/macos-sequoia-xcode:16.4`
- `ghcr.io/cirruslabs/macos-tahoe-xcode:26` (preview)

## Development Workflow

### Local Development
```bash
# 1. Build development environment
pwsh ./scripts/build.ps1 -ImageType maui -MacOSVersion sequoia -DotnetChannel 10.0

# 2. Run with project directory mounted
tart run maui-dev-sequoia --dir myproject:/path/to/project

# 3. Access project in VM at /Volumes/My Shared Files/myproject
# 4. Build and test as normal
```

### CI/CD Integration
```bash
# Use in CI pipeline (set env vars to auto-register runner)
export GITHUB_ORG=your-org
export GITHUB_TOKEN=ghp_xxx
tart run maui-dev-sequoia

# Publish to registry for reuse
tart push maui-dev-sequoia your-registry/maui-dev-sequoia:latest
```

### Image Management
```bash
# List available images
tart list

# Clean up unused images
tart prune

# Push to registry
tart push maui-dev-sequoia your-registry/maui-dev-sequoia:latest
```

## Prerequisites

Required tools (checked by `quick-start.ps1`):
- **Tart**: `brew install cirruslabs/cli/tart`
- **Packer**: `brew install packer`
- **PowerShell**: Available as `pwsh`
- **Ansible** (optional): `brew install ansible`

## Integration Notes

- Compatible with parent repository's `MauiProvisioning` PowerShell module
- Uses same .NET workload resolution logic as Docker builds
- Shares configuration patterns with container build system
- VM images can be used alongside Docker containers for hybrid workflows

## Common Parameters

Build scripts accept:
- `ImageType`: "maui" or "ci"
- `MacOSVersion`: "sequoia" or "tahoe"
- `DotnetChannel`: "9.0" or "10.0"
- `XcodeVersion`: Auto-resolved from platform matrix if not specified
- `CPUCount`, `MemoryGB`: Resource allocation
- `Push`: Push to registry
- `DryRun`: Preview actions without execution
