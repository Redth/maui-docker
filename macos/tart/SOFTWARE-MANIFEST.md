# Software Manifest

The MAUI Tart VM images include a comprehensive software manifest similar to [GitHub Actions runner images](https://github.com/actions/runner-images).

## Location

The software manifest is generated during the image build and saved to:

```
/usr/local/share/installed-software.md
```

For convenience, a symlink is also created in the home directory:

```
~/installed-software.md
```

Both paths point to the same file.

## Contents

The manifest includes detailed information about:

### System Information
- macOS version and build number
- Kernel version
- Architecture (arm64/x86_64)
- Image build date

### Development Tools
- **Xcode**: All installed versions, SDKs, and simulators
- **.NET**: SDK versions, runtimes, workloads, and global tools
- **Android**: SDK platforms, build tools, and NDK versions
- **Languages**: Node.js, Python, Ruby, Java versions
- **Package Managers**: Homebrew, npm, gem, CocoaPods
- **Utilities**: Git, curl, wget, jq, gh, cmake, fastlane, etc.

### Environment Variables
Standard paths and configuration for:
- DOTNET_ROOT
- ANDROID_HOME / ANDROID_SDK_ROOT
- JAVA_HOME

### CI/CD Runner Support
Information about GitHub Actions and Gitea Actions runner capabilities

### Build Information
- Base image details
- .NET channel and workload set version
- Xcode versions included
- Build date and configuration

## Viewing the Manifest

### Inside a Running VM

```bash
# SSH into the VM
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0)

# View the manifest (easy path in home directory)
cat ~/installed-software.md

# Or open in less for easier navigation
less ~/installed-software.md

# Or use the full path
cat /usr/local/share/installed-software.md
```

### From the Host

```bash
# Start VM and get IP
tart run maui-dev-tahoe-dotnet10.0 &
sleep 10
VM_IP=$(tart ip maui-dev-tahoe-dotnet10.0)

# Copy manifest to host (using convenient home directory path)
scp admin@${VM_IP}:installed-software.md ./

# View locally
cat installed-software.md
```

### Extract from Image Without Running

```bash
# Clone the image if not already local
tart clone ghcr.io/redth/maui-dev-tahoe-dotnet10.0 maui-dev-tahoe-dotnet10.0

# Mount the image filesystem (requires root)
# Note: This is advanced usage and may vary by macOS version
```

## Format

The manifest follows the same markdown structure as GitHub Actions runner images:

1. **Operating System** - Version and build info
2. **Xcode** - All versions and SDKs
3. **.NET** - SDKs, runtimes, workloads
4. **Android** - SDK components
5. **Languages and Runtimes** - Version list
6. **Package Managers** - Installed managers and versions
7. **Development Tools** - Utilities and CLI tools
8. **Homebrew Packages** - Complete list (expandable section)
9. **iOS Simulators** - Available device types (expandable section)
10. **Environment Variables** - Standard paths
11. **CI/CD Runner Support** - Configuration info
12. **Build Information** - Detailed build metadata (expandable section)

## Use Cases

### Verify Tool Availability
Check if a specific tool or version is available before configuring CI/CD workflows:

```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "grep -A 5 'Node.js' ~/installed-software.md"
```

### Troubleshooting
When debugging build issues, check the exact versions installed:

```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "grep -A 20 '## .NET' ~/installed-software.md"
```

### Documentation
Reference the manifest in your project documentation to specify required VM image versions.

### Auditing
Track what software is included in each image version for compliance or security auditing.

## Comparison with GitHub Actions

Like GitHub's hosted runners, our manifests provide:
- ✅ Complete software inventory
- ✅ Version information for all tools
- ✅ Environment variable documentation
- ✅ Expandable sections for detailed listings
- ✅ Build date and base image tracking

Unlike GitHub's runners:
- Our manifests are generated inside the VM (not in a separate repository)
- We focus on MAUI/.NET development tools
- We include Tart/VM-specific information
- We document multiple CI runner support (GitHub + Gitea)

## Standard Compliance

The manifest format follows the de facto standard established by GitHub Actions runner-images project, making it familiar to developers and compatible with existing tooling that parses these manifests.

## Generating Updated Manifests

The manifest is automatically generated during image builds. To manually regenerate:

```bash
# Inside the VM
/tmp/generate-software-manifest.sh /usr/local/share/installed-software.md
```

The generation script is located at:
- Build-time: `macos/tart/scripts/generate-software-manifest.sh`
- Runtime: Available in VM at `/tmp/` during provisioning

## Related Files

- **Software Manifest**: `/usr/local/share/installed-software.md` (human-readable markdown)
- **Build Info**: `/usr/local/share/build-info.json` (machine-readable JSON)
- **Runner Setup**: See `RUNNER-SETUP.md` in repository for CI/CD configuration

## Contributing

If you notice missing information in the manifest or have suggestions for additional sections, please open an issue or pull request in the repository.
