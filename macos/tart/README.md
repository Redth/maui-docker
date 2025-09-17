# Tart VM Images for MAUI Development

This directory contains scripts and templates for building custom macOS VM images using [Cirrus Labs Tart](https://tart.run/) for .NET MAUI development.

## Overview

Tart VMs provide a Docker-like experience for macOS, allowing you to:
- Create reproducible development environments
- Run CI/CD pipelines on macOS
- Provision multiple macOS versions with different tool configurations
- Share development environments across teams

## Directory Structure

```
tart/
├── templates/          # Packer templates for VM creation
│   ├── base.pkr.hcl   # Base macOS image with homebrew
│   ├── maui.pkr.hcl   # MAUI development image
│   └── ci.pkr.hcl     # CI/CD runner image
├── scripts/           # Build and automation scripts
│   ├── build.ps1      # Main build script
│   ├── provision.sh   # VM provisioning script
│   └── test.ps1       # Image testing script
├── ansible/           # Ansible playbooks for configuration
│   ├── base.yml       # Base system configuration
│   ├── maui.yml       # MAUI tooling setup
│   └── xcode.yml      # Xcode installation
├── config/            # Configuration files
│   ├── variables.json # Build variables
│   └── .cirrus.yml    # Cirrus CI configuration
└── README.md          # This file
```

## Prerequisites

1. **Tart**: Install via Homebrew
   ```bash
   brew install cirruslabs/cli/tart
   ```

2. **Packer**: For automated image building
   ```bash
   brew install packer
   ```

3. **Ansible** (optional): For advanced configuration
   ```bash
   brew install ansible
   ```

## Quick Start

### 1. Build Base Image
```bash
pwsh ./scripts/build.ps1 -ImageType base -MacOSVersion sequoia
```

### 2. Build MAUI Development Image
```bash
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0 -MacOSVersion sequoia
```

### 3. Run a VM
```bash
tart run maui-dev-sequoia
```

### 4. Test Built Image
```bash
pwsh ./scripts/test.ps1 -ImageName maui-dev-sequoia
```

## Image Types

### Base Image (`base.pkr.hcl`)
- Clean macOS installation
- Homebrew package manager
- SSH access configured
- Basic development tools

### MAUI Development Image (`maui.pkr.hcl`)
- Extends base image
- .NET SDK and MAUI workloads
- Xcode and iOS simulators
- Android SDK and tools
- Visual Studio Code

### CI/CD Runner Image (`ci.pkr.hcl`)
- Extends MAUI image
- GitHub Actions runner
- Additional CI tools
- Optimized for automation

## Configuration

Edit `config/variables.json` to customize:
- macOS version
- .NET channel
- Xcode version
- Package versions
- Resource allocation

## Usage Examples

### Development Workflow
```bash
# Build and start development environment
pwsh ./scripts/build.ps1 -ImageType maui -DotnetChannel 10.0
tart run maui-dev-sequoia --dir project:/path/to/your/project

# Inside VM - access project at /Volumes/My Shared Files/project
cd "/Volumes/My Shared Files/project"
dotnet build
```

### CI/CD Integration
```yaml
# .cirrus.yml
task:
  name: maui-build
  macos_instance:
    image: your-registry/maui-dev-sequoia:latest
  build_script:
    - dotnet restore
    - dotnet build
    - dotnet test
```

## Best Practices

1. **Layered Approach**: Build images in layers (base → maui → ci)
2. **Version Pinning**: Pin specific versions in templates
3. **Resource Management**: Allocate appropriate CPU/memory
4. **Directory Mounting**: Use `--dir` for project access
5. **SSH Access**: Configure for automation and debugging
6. **Image Registry**: Push to container registry for sharing

## Troubleshooting

### Common Issues
- **SSH Connection**: Ensure VM has SSH enabled
- **Directory Mounting**: Requires macOS 13+ on host and guest
- **Performance**: Allocate sufficient resources for Xcode builds
- **Networking**: Configure bridge networking for external access

### Debugging
```bash
# SSH into running VM
tart ip <vm-name>
ssh admin@<ip-address>

# View VM logs
tart log <vm-name>

# List running VMs
tart list
```

## Integration with Existing Provisioning

The Tart images can use the same `MauiProvisioning` module:
```bash
# Inside VM
pwsh /path/to/provision.ps1 -DotnetChannel 10.0
```

This ensures consistency between containerized Docker environments and Tart VMs.