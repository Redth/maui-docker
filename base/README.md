# MAUI Docker Base Images

This directory contains Docker base images that provide a complete .NET MAUI development environment without the GitHub Actions runner. These images are designed to be used as base images for other containers that need MAUI development capabilities.

## What's Included

### Both Linux and Windows images include:
- **.NET SDK** - Latest .NET SDK with MAUI workloads
- **Android SDK** - Complete Android development environment
- **Java/OpenJDK** - Required Java runtime for Android development
- **PowerShell** - Cross-platform PowerShell (Linux images)
- **Development Tools** - Git, build tools, and other essential development utilities

### Linux-specific additions:
- **Supervisor** - Process management for running multiple services
- **Standard development tools** - curl, wget, unzip, etc.

### Windows-specific additions:
- **Chocolatey** - Package manager for Windows
- **Windows development tools** - Essential Windows development utilities

## Usage

These base images can be used as the foundation for:
- MAUI development containers
- CI/CD build agents (without GitHub Actions runner)
- Development environments
- Custom runner implementations

### Example Dockerfile using the base image:

```dockerfile
FROM redth/maui-docker-base:linux-latest

# Add your custom requirements here
COPY your-app /app
WORKDIR /app

# Your custom commands
RUN dotnet restore
RUN dotnet build

CMD ["dotnet", "run"]
```

## Building the Images

### Linux:
```powershell
./linux/build.ps1 -DockerRepository "your-repo/maui-docker-base" -Version "your-tag"
```

### Windows:
```powershell
./windows/build.ps1 -DockerRepository "your-repo/maui-docker-base" -Version "your-tag"
```

### Both platforms:
```powershell
# Build Linux
./base-build.ps1 -DockerPlatform "linux/amd64" -DockerRepository "your-repo/maui-docker-base"

# Build Windows  
./base-build.ps1 -DockerPlatform "windows/amd64" -DockerRepository "your-repo/maui-docker-base"
```

## Relationship to Runner Images

The GitHub Actions runner images (`../runner/`) now derive from these base images, providing a cleaner separation of concerns:

```
Base Image (MAUI Dev Environment) 
    ↓
Runner Image (Base + GitHub Actions Runner)
```

This approach reduces duplication and makes it easier to maintain both environments separately.

## Environment Variables

The base images support the following environment variables for customization:

- `INIT_BASH_SCRIPT` - Path to custom bash initialization script (Linux)
- `INIT_PWSH_SCRIPT` - Path to custom PowerShell initialization script (Both)
- `ANDROID_HOME` - Android SDK location (set automatically)
- `JAVA_HOME` - Java installation location (set automatically)
- `LOG_PATH` - Logging directory (set automatically)

## Default Command

- **Linux**: `tail -f /dev/null` (keeps container running)
- **Windows**: PowerShell infinite loop (keeps container running)

These commands allow the containers to stay alive for interactive use or as base images for other services.
