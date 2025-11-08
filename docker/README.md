# MAUI Docker Images

This directory contains Docker images that provide a complete .NET MAUI development environment with optional GitHub Actions and Gitea Actions runner support. These images are designed to be used both as standalone development environments and as self-hosted runners.

## Structure

- `linux/` - Linux MAUI development images
- `windows/` - Windows MAUI development images  
- `test/` - Android emulator + Appium test images (Linux only)
- `build.ps1` - Cross-platform build script for Linux and Windows images

## What's Included

### Both Linux and Windows images include:
- **.NET SDK** - Latest .NET SDK with MAUI workloads
- **Android SDK** - Complete Android development environment
- **Java/OpenJDK** - Required Java runtime for Android development
- **PowerShell** - Cross-platform PowerShell (Linux images)
- **Development Tools** - Git, build tools, and other essential development utilities
- **GitHub Actions Runner** - GitHub Actions self-hosted runner (optional, enabled via environment variables)
- **Gitea Actions Runner** - Gitea Actions self-hosted runner (optional, enabled via environment variables)

### Linux-specific additions:
- **Supervisor** - Process management for running multiple services
- **Standard development tools** - curl, wget, unzip, etc.

### Windows-specific additions:
- **Chocolatey** - Package manager for Windows
- **Windows development tools** - Essential Windows development utilities

## Usage

These base images can be used in three modes:

1. **Development Environment** - Use without runner environment variables for local development
2. **GitHub Actions Self-Hosted Runner** - Set GitHub environment variables to enable the runner
3. **Gitea Actions Self-Hosted Runner** - Set Gitea environment variables to enable the runner
4. **Both Runners** - Set both GitHub and Gitea environment variables to run both runners simultaneously

### As a Development Container

```bash
docker run -it ghcr.io/maui-containers/maui-linux:dotnet9.0 bash
```

### As a GitHub Actions Runner

```bash
docker run -d \
  -e GITHUB_ORG=your-org \
  -e GITHUB_TOKEN=your-token \
  -e LABELS=maui,linux,self-hosted \
  ghcr.io/maui-containers/maui-linux:dotnet9.0
```

### As a Gitea Actions Runner

```bash
docker run -d \
  -e GITEA_INSTANCE_URL=https://gitea.example.com \
  -e GITEA_RUNNER_TOKEN=your-token \
  -e GITEA_RUNNER_LABELS=maui,linux,amd64 \
  ghcr.io/maui-containers/maui-linux:dotnet9.0
```

### As Both Runners Simultaneously

```bash
docker run -d \
  -e GITHUB_ORG=your-org \
  -e GITHUB_TOKEN=your-github-token \
  -e GITEA_INSTANCE_URL=https://gitea.example.com \
  -e GITEA_RUNNER_TOKEN=your-gitea-token \
  ghcr.io/maui-containers/maui-linux:dotnet9.0
```

### Example Dockerfile using the base image:

```dockerfile
FROM ghcr.io/maui-containers/maui-linux:dotnet9.0

# Add your custom requirements here
COPY your-app /app
WORKDIR /app

# Your custom commands
RUN dotnet restore
RUN dotnet build

CMD ["dotnet", "run"]
```

## Building the Images

### Using the unified build script (recommended):
```powershell
# Build Linux
./build.ps1 -DockerPlatform "linux/amd64" -DockerRepository "your-repo/maui-build"

# Build Windows  
./build.ps1 -DockerPlatform "windows/amd64" -DockerRepository "your-repo/maui-build"
```

### Using platform-specific scripts:
```powershell
# Linux
./linux/build.ps1 -DockerRepository "your-repo/maui-build" -Version "your-tag"

# Windows
./windows/build.ps1 -DockerRepository "your-repo/maui-build" -Version "your-tag"
```

## Relationship to Separate Runner Images

All Docker images now include integrated runner support for both GitHub Actions and Gitea Actions. This provides:

- **Simpler architecture** - One image type instead of three
- **Flexibility** - Choose which runner(s) to enable at runtime via environment variables
- **Consistency** - Same approach as macOS tart images
- **Reduced maintenance** - Single codebase for runner functionality

## Environment Variables

### Development Environment Variables

- `INIT_BASH_SCRIPT` - Path to custom bash initialization script (Linux)
- `INIT_PWSH_SCRIPT` - Path to custom PowerShell initialization script (Both)
- `ANDROID_HOME` - Android SDK location (set automatically)
- `JAVA_HOME` - Java installation location (set automatically)
- `LOG_PATH` - Logging directory (set automatically)

### GitHub Actions Runner Variables

Set these to enable the GitHub Actions runner:

- `GITHUB_ORG` - **Required** GitHub organization or user name
- `GITHUB_TOKEN` - **Required** GitHub personal access token with runner registration permissions
- `GITHUB_REPO` - Optional repository name (registers at org level if not set)
- `RUNNER_NAME` - Optional custom runner name
- `RUNNER_NAME_PREFIX` - Runner name prefix (default: "maui-runner")
- `RANDOM_RUNNER_SUFFIX` - Use random suffix for runner name (default: "true")
- `RUNNER_WORKDIR` - Custom work directory for the runner
- `RUNNER_GROUP` - Runner group name (default: "Default")
- `LABELS` - Comma-separated list of custom labels
- `EPHEMERAL` - Enable ephemeral runner mode (runner is removed after one job)
- `DISABLE_AUTO_UPDATE` - Disable automatic runner updates
- `NO_DEFAULT_LABELS` - Remove default labels (self-hosted, OS, architecture)

### Gitea Actions Runner Variables

Set these to enable the Gitea Actions runner:

- `GITEA_INSTANCE_URL` - **Required** Gitea instance URL (e.g., https://gitea.example.com)
- `GITEA_RUNNER_TOKEN` - **Required** Gitea runner registration token
- `GITEA_RUNNER_NAME` - Optional custom runner name
- `GITEA_RUNNER_NAME_PREFIX` - Runner name prefix (default: "gitea-runner")
- `RANDOM_RUNNER_SUFFIX` - Use random suffix for runner name (default: "true")
- `GITEA_RUNNER_LABELS` - Comma-separated list of labels (default: "maui,linux,amd64" or "maui,windows,amd64")

### Running Both Runners

Both runners can be enabled simultaneously by setting both GitHub and Gitea environment variables. The runners will run in parallel within the container.

## Default Command

- **Linux**: `tail -f /dev/null` (keeps container running)
- **Windows**: PowerShell infinite loop (keeps container running)

These commands allow the containers to stay alive for interactive use or as base images for other services.
