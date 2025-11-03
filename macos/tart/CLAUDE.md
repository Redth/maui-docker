# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This directory contains Tart VM (Cirrus Labs Tart) infrastructure for building macOS VM images optimized for .NET MAUI development and CI/CD workflows. Tart provides Docker-like virtualization for macOS environments.

## Build Commands

### Building VM Images
```powershell
# Build with .NET 10.0 (auto-resolves to tahoe + Xcode 26)
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0

# Build with .NET 9.0 (auto-resolves to tahoe + Xcode 26)
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 9.0

# Build with additional Xcode versions installed
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0 -AdditionalXcodeVersions "16.4","16.1"

# Override macOS/Xcode versions if needed
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0 -MacOSVersion sequoia -BaseXcodeVersion 16.4

# Quick start with all prerequisites check and build
pwsh ./scripts/quick-start.ps1 -BuildType maui -DotnetChannel 10.0
```

### Testing Images
```powershell
# Test .NET 10.0 image
pwsh ./scripts/test.ps1 -ImageName maui-dev-tahoe-dotnet10.0 -TestType maui

# Test .NET 9.0 image
pwsh ./scripts/test.ps1 -ImageName maui-dev-tahoe-dotnet9.0 -TestType maui
```

### Runner Auto-registration

**GitHub Actions Runner:**
```powershell
$env:GITHUB_ORG = 'your-org'
$env:GITHUB_TOKEN = 'ghp_xxx'
tart run maui-dev-tahoe-dotnet10.0
```

**Gitea Actions Runner:**
```powershell
$env:GITEA_INSTANCE_URL = 'https://gitea.example.com'
$env:GITEA_RUNNER_TOKEN = 'your-registration-token'
tart run maui-dev-tahoe-dotnet10.0
```

### VM Management
```bash
# Run VM with project directory mounted
tart run maui-dev-tahoe-dotnet10.0 --dir project:/path/to/your/project

# List VMs and get IP for SSH access
tart list
tart ip maui-dev-tahoe-dotnet10.0

# SSH into running VM
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0)
```

### Managing Multiple Xcode Versions
When additional Xcode versions are installed, you can manage them using the `xcodes` CLI:

```bash
# List all installed Xcode versions
xcodes installed

# Switch to a specific Xcode version
sudo xcodes select 16.4

# Verify the currently active Xcode
xcodebuild -version
xcrun --show-sdk-path

# List available Xcode versions to install
xcodes list
```

**Note**: The base Xcode version comes from the upstream Cirrus Labs base image and is pre-installed. Additional versions are installed during the image build using the `xcodes` tool.

## Architecture

### Image Hierarchy
```
Cirrus Labs Base macOS Image (macos-tahoe-xcode:26 or macos-sequoia-xcode:16.4)
    ↓
MAUI Development Image (maui.pkr.hcl)
    - .NET SDK + MAUI workloads
    - Xcode tooling + iOS simulators
    - Android SDK + development tools
    - VS Code + development utilities
    - GitHub Actions runner helper script (auto-registration via env vars)
    - Gitea Actions runner helper script (auto-registration via env vars)
```

### Configuration System

**Platform Matrix (`config/platform-matrix.json`)**:
- Defines macOS versions (sequoia, tahoe) and their Xcode compatibility
- Maps each .NET channel to a specific macOS/Xcode version combination
- Each .NET channel has a single default configuration (not a matrix)
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

The build system automatically resolves macOS and Xcode versions based on the .NET channel:

**Per-Channel Defaults** (defined in `config/platform-matrix.json`):
- **.NET 9.0**: macOS Tahoe 16 + Xcode 26 (stable, pinned via SHA256)
- **.NET 10.0**: macOS Tahoe 16 + Xcode 26 (preview/RC, pinned via SHA256)

**Auto-Resolution**:
- If `-MacOSVersion` not specified, uses the version defined for the .NET channel
- If `-BaseXcodeVersion` not specified, uses the version defined for the .NET channel
- If `-AdditionalXcodeVersions` not specified, uses the array defined in the .NET channel (default: empty)
- Validates macOS/Xcode/.NET channel compatibility
- Supports both stable (.NET 9.0) and preview (.NET 10.0) channels

**Multiple Xcode Versions**:
- **Base Xcode**: Comes from the upstream Cirrus Labs base image (e.g., `macos-tahoe-xcode:26@sha256:...`)
- **Additional Xcodes**: Optionally install more versions during build using `-AdditionalXcodeVersions`
- **Configuration**: Define in `platform-matrix.json` under `AdditionalXcodeVersions` array
- **Runtime Switching**: Use `xcodes select` command to switch between installed versions

**Variations**: Use git branches if you need to build different macOS/Xcode combinations in parallel

### Base Images

Uses Cirrus Labs public base images:
- `ghcr.io/cirruslabs/macos-sequoia-xcode:16.4`
- `ghcr.io/cirruslabs/macos-tahoe-xcode@sha256:49c83cf0...` (pinned to specific digest)

**Note**: We use SHA256 manifest digests to pin base images to specific versions, preventing automatic updates when Cirrus Labs publishes new builds under the same tag.

**Updating Base Image Digest**:
```bash
# Get the manifest digest for a tag (NOT config digest)
docker manifest inspect ghcr.io/cirruslabs/macos-tahoe-xcode:26 --verbose | jq -r '.Descriptor.digest'

# Update platform-matrix.json with the new digest
# Format: "@sha256:abc123..." (no tag prefix, just the digest)
```

## Development Workflow

### Local Development
```bash
# 1. Build development environment (.NET 10.0 auto-resolves to tahoe + Xcode 26)
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0

# 2. Run with project directory mounted
tart run maui-dev-tahoe-dotnet10.0 --dir myproject:/path/to/project

# 3. Access project in VM at /Volumes/My Shared Files/myproject
# 4. Build and test as normal
```

### CI/CD Integration

**GitHub Actions:**
```bash
# Use in CI pipeline (set env vars to auto-register runner)
export GITHUB_ORG=your-org
export GITHUB_TOKEN=ghp_xxx
tart run maui-dev-tahoe-dotnet10.0
```

**Gitea Actions:**
```bash
# Use in CI pipeline (set env vars to auto-register runner)
export GITEA_INSTANCE_URL=https://gitea.example.com
export GITEA_RUNNER_TOKEN=your-registration-token
export GITEA_RUNNER_NAME=maui-runner-1  # Optional, auto-generated if not set
export GITEA_RUNNER_LABELS=macos,maui,arm64  # Optional, defaults shown
tart run maui-dev-tahoe-dotnet10.0
```

**Publishing Images:**
```bash
# Publish to registry for reuse
tart push maui-dev-tahoe-dotnet10.0 your-registry/maui-dev-tahoe-dotnet10.0:latest
```

### Image Management
```bash
# List available images
tart list

# Clean up unused images
tart prune

# Push to registry (both .NET versions use tahoe, differentiated by .NET version)
tart push maui-dev-tahoe-dotnet9.0 your-registry/maui-dev-tahoe-dotnet9.0:latest
tart push maui-dev-tahoe-dotnet10.0 your-registry/maui-dev-tahoe-dotnet10.0:latest
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

## CI Runner Configuration

### GitHub Actions Runner

The VM includes a GitHub Actions runner helper script at `/Users/admin/actions-runner/maui-runner.sh` that auto-registers when environment variables are set.

**Required Environment Variables:**
- `GITHUB_ORG` - GitHub organization name
- `GITHUB_TOKEN` - GitHub personal access token with runner registration permissions

**Optional Environment Variables:**
- `GITHUB_REPO` - Repository name (if not set, registers as org-level runner)
- `RUNNER_NAME` - Custom runner name (auto-generated if not set)
- `RUNNER_NAME_PREFIX` - Prefix for auto-generated names (default: "github-runner")
- `RANDOM_RUNNER_SUFFIX` - Add random suffix to name (default: "true")
- `RUNNER_WORKDIR` - Work directory for runner
- `RUNNER_GROUP` - Runner group (default: "Default")
- `LABELS` - Custom labels (default: "default")
- `EPHEMERAL` - Enable ephemeral mode (runner deleted after one job)
- `DISABLE_AUTO_UPDATE` - Disable automatic runner updates
- `NO_DEFAULT_LABELS` - Remove default labels
- `INIT_PWSH_SCRIPT` - PowerShell script to run before registration
- `INIT_BASH_SCRIPT` - Bash script to run before registration

### Gitea Actions Runner

The VM includes a Gitea Actions runner (act_runner) at `/Users/admin/gitea-runner/gitea-runner.sh` that auto-registers when environment variables are set.

**Required Environment Variables:**
- `GITEA_INSTANCE_URL` - Gitea instance URL (e.g., "https://gitea.example.com")
- `GITEA_RUNNER_TOKEN` - Runner registration token from Gitea

**Optional Environment Variables:**
- `GITEA_RUNNER_NAME` - Custom runner name (auto-generated if not set)
- `GITEA_RUNNER_NAME_PREFIX` - Prefix for auto-generated names (default: "gitea-runner")
- `GITEA_RUNNER_LABELS` - Comma-separated labels (default: "macos,maui,arm64")
- `GITEA_RUNNER_ROOT` - Runner installation directory (default: "/Users/admin/gitea-runner")
- `RANDOM_RUNNER_SUFFIX` - Add random suffix to name (default: "true")
- `GITEA_RUNNER_NO_INTERACTIVE` - Disable interactive prompts during registration
- `INIT_PWSH_SCRIPT` - PowerShell script to run before registration
- `INIT_BASH_SCRIPT` - Bash script to run before registration

**Getting a Gitea Runner Token:**
```bash
# In Gitea UI: Settings → Actions → Runners → Create New Runner
# Or use Gitea CLI/API to generate a registration token
```

## Common Parameters

Build scripts accept:
- `ImageType`: "maui" or "ci"
- `DotnetChannel`: "9.0" or "10.0" (required - determines macOS/Xcode versions)
- `MacOSVersion`: Auto-resolved from .NET channel (both currently use "tahoe")
- `BaseXcodeVersion`: Auto-resolved from .NET channel (both currently use "@sha256:..." for pinning)
- `AdditionalXcodeVersions`: Array of additional Xcode versions to install (e.g., `@("16.4", "16.1")`)
- `ImageName`: Auto-generated as `maui-dev-{macos}-dotnet{version}` (e.g., `maui-dev-tahoe-dotnet10.0`)
- `CPUCount`, `MemoryGB`: Resource allocation
- `Push`: Push to registry
- `DryRun`: Preview actions without execution

### Example with Multiple Xcode Versions

To configure default additional Xcode versions in `config/platform-matrix.json`:
```json
{
  "DotnetChannels": {
    "10.0": {
      "BaseXcodeVersion": "@sha256:49c83cf0989d5c3039b8f1a5c543aa25b2cd920784fdaf30be22e18e4edeaa95",
      "AdditionalXcodeVersions": ["16.4", "16.1"],
      ...
    }
  }
}
```

Or override at build time:
```powershell
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0 -AdditionalXcodeVersions "16.4","15.4"
```
