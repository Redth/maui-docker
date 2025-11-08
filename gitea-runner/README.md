# Gitea Actions Runner Images

Docker images with .NET MAUI development environment and Gitea Actions runner pre-installed.

## Overview

These images extend the base MAUI images with the Gitea Actions runner (act_runner), allowing you to use them as self-hosted runners for Gitea Actions workflows.

## Quick Start

### Building Images

```powershell
# Linux
./gitea-runner/linux/build.ps1 -DotnetVersion "10.0"

# Windows
./gitea-runner/windows/build.ps1 -DotnetVersion "10.0"
```

### Running a Runner

```bash
# Linux
docker run -d \
  -e GITEA_INSTANCE_URL="https://gitea.example.com" \
  -e GITEA_RUNNER_TOKEN="your-registration-token" \
  -e GITEA_RUNNER_NAME="maui-linux-1" \
  -e GITEA_RUNNER_LABELS="maui,linux,amd64,dotnet10" \
  maui-containers/maui-gitea-runner-linux:dotnet10.0

# Windows
docker run -d `
  -e GITEA_INSTANCE_URL="https://gitea.example.com" `
  -e GITEA_RUNNER_TOKEN="your-registration-token" `
  -e GITEA_RUNNER_NAME="maui-windows-1" `
  -e GITEA_RUNNER_LABELS="maui,windows,amd64,dotnet10" `
  maui-containers/maui-gitea-runner-windows:dotnet10.0
```

## Getting a Runner Token

To register a runner with Gitea, you need a registration token:

1. **Via Gitea UI:**
   - Navigate to your Gitea instance
   - Go to Settings → Actions → Runners
   - Click "Create New Runner"
   - Copy the registration token

2. **Via Gitea API:**
   ```bash
   # Organization-level runner
   curl -X POST "https://gitea.example.com/api/v1/orgs/{org}/actions/runners/registration-token" \
     -H "Authorization: token YOUR_GITEA_TOKEN"

   # Repository-level runner
   curl -X POST "https://gitea.example.com/api/v1/repos/{owner}/{repo}/actions/runners/registration-token" \
     -H "Authorization: token YOUR_GITEA_TOKEN"
   ```

## Environment Variables

### Required
- `GITEA_INSTANCE_URL` - Your Gitea instance URL (e.g., "https://gitea.example.com")
- `GITEA_RUNNER_TOKEN` - Runner registration token from Gitea

### Optional
- `GITEA_RUNNER_NAME` - Custom runner name (auto-generated if not set)
- `GITEA_RUNNER_NAME_PREFIX` - Prefix for auto-generated names (default: "gitea-runner")
- `RANDOM_RUNNER_SUFFIX` - Add random suffix to name (default: "true")
- `GITEA_RUNNER_LABELS` - Comma-separated labels
  - Linux default: "maui,linux,amd64"
  - Windows default: "maui,windows,amd64"
- `INIT_PWSH_SCRIPT` - PowerShell script to run before registration
- `INIT_BASH_SCRIPT` - Bash script to run before registration (Linux only)

## Example Workflow

```yaml
name: Build MAUI App
on: [push]

jobs:
  build:
    runs-on: [maui, linux]  # Uses runner with these labels
    steps:
      - uses: actions/checkout@v4

      - name: Build Android
        run: dotnet build -f net10.0-android

      - name: Build iOS
        run: dotnet build -f net10.0-ios
```

## Image Tags

Images are tagged with multiple formats:
- `linux-dotnet10.0` - Platform and .NET version
- `linux-dotnet10.0-latest` - Platform, .NET version, and custom version
- `linux-dotnet10.0-workloads10.0.100-rc.1.24557.12` - Includes workload set version
- `linux-dotnet10.0-workloads10.0.100-rc.1.24557.12-vlatest` - All details

## Base Image Dependency

These images depend on the base MAUI images. Build the base image first:

```powershell
# Build base image
./base/base-build.ps1 -DotnetVersion "10.0" -DockerPlatform "linux/amd64"

# Then build Gitea runner image
./gitea-runner/gitea-runner-build.ps1 -DotnetVersion "10.0" -DockerPlatform "linux/amd64"
```

## Platform Support

- **Linux:** `linux/amd64` - Fully supported
- **Windows:** `windows/amd64` - Fully supported

## Differences from GitHub Actions Runner

- Uses `act_runner` binary instead of GitHub's runner
- Different registration process (token-based vs. OAuth)
- No automatic runner removal on shutdown (remove from Gitea UI if needed)
- Different configuration file format

## Troubleshooting

### Runner won't register
- Verify `GITEA_INSTANCE_URL` is correct and accessible
- Check that `GITEA_RUNNER_TOKEN` is valid and not expired
- Ensure network connectivity to Gitea instance

### Runner registered but not picking up jobs
- Check runner labels match workflow requirements
- Verify runner is online in Gitea UI (Settings → Actions → Runners)
- Check container logs: `docker logs <container-id>`

### Permission issues (Linux)
- Ensure proper file permissions in mounted volumes
- Runner runs as user `mauiusr` (UID 1400, GID 1401)

## More Information

- See main [CLAUDE.md](../CLAUDE.md) for comprehensive documentation
- Gitea Actions: https://docs.gitea.com/usage/actions/overview
- act_runner: https://gitea.com/gitea/act_runner
