# Software Manifest

The MAUI Tart VM images include comprehensive software manifests similar to [GitHub Actions runner images](https://github.com/actions/runner-images), available in both human-readable and machine-readable formats.

## Formats

### Markdown (Human-Readable)

**Location:** `/usr/local/share/installed-software.md`
**Symlink:** `~/installed-software.md`

Formatted markdown document with detailed descriptions, examples, and expandable sections. Perfect for viewing in a terminal or browser.

### JSON (Machine-Readable)

**Location:** `/usr/local/share/installed-software.json`
**Symlink:** `~/installed-software.json`

Structured JSON document with the same information in a queryable format. Perfect for automation, CI/CD scripts, and programmatic access.

Both formats contain identical information - choose based on your use case.

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

**Using Markdown:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "grep -A 5 'Node.js' ~/installed-software.md"
```

**Using JSON:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.languages.node' ~/installed-software.json"
```

### Troubleshooting

**Using Markdown:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "grep -A 20 '## .NET' ~/installed-software.md"
```

**Using JSON:**
```bash
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.dotnet' ~/installed-software.json"
```

### Programmatic Queries

The JSON format is ideal for automation:

```bash
# Check if a specific .NET workload is installed
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.dotnet.workloads | contains([\"maui\"])' ~/installed-software.json"

# Get all installed Xcode versions
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq -r '.xcode.installedVersions[]' ~/installed-software.json"

# Find a specific Homebrew package
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  "jq '.homebrewPackages[] | select(.name == \"git\")' ~/installed-software.json"

# Check minimum tool version requirements
ssh admin@$(tart ip maui-dev-tahoe-dotnet10.0) \
  'jq -r ".languages.node" ~/installed-software.json | \
   awk -F. "{if (\$1 >= 18) print \"OK\"; else print \"Version too old\"}"'
```

### Documentation
Reference the manifest in your project documentation to specify required VM image versions.

### Auditing
Track what software is included in each image version for compliance or security auditing.

## JSON Structure

The JSON manifest follows this schema:

```json
{
  "manifestVersion": "1.0",
  "imageType": "maui-development",
  "generatedAt": "2025-01-05T12:00:00Z",
  "operatingSystem": {
    "productVersion": "16.0",
    "buildVersion": "25A123",
    "kernelVersion": "25.0.0",
    "architecture": "arm64"
  },
  "xcode": {
    "defaultVersion": "26.0",
    "defaultBuild": "26A123",
    "installedVersions": ["26.0", "16.4"],
    "sdks": ["iphoneos18.0", "macosx16.0", "appletvos18.0"]
  },
  "dotnet": {
    "version": "10.0.100",
    "sdks": [{"version": "10.0.100", "path": "..."}],
    "runtimes": [{"name": "Microsoft.NETCore.App", "version": "10.0.0"}],
    "workloads": ["maui", "wasm-tools"],
    "globalTools": [{"name": "AndroidSdk.Tool", "version": "1.0.0"}]
  },
  "android": {
    "sdkRoot": "/Users/admin/Library/Android/sdk",
    "platforms": ["platforms;android-35", "platforms;android-34"],
    "buildTools": ["build-tools;35.0.0", "build-tools;34.0.0"]
  },
  "languages": {
    "node": "20.11.0",
    "npm": "10.2.4",
    "python": "3.12.1",
    "ruby": "3.3.0",
    "java": "17.0.10",
    "git": "2.43.0"
  },
  "packageManagers": {
    "homebrew": "4.2.0",
    "gem": "3.5.3",
    "cocoapods": "1.15.0"
  },
  "tools": {
    "curl": "8.5.0",
    "jq": "1.7.1",
    "gh": "2.42.0"
  },
  "homebrewPackages": [
    {"name": "git", "version": "2.43.0"},
    {"name": "node", "version": "20.11.0"}
  ],
  "environmentVariables": {
    "DOTNET_ROOT": "/Users/admin/.dotnet",
    "ANDROID_HOME": "~/Library/Android/sdk"
  },
  "ciRunners": {
    "githubActions": {
      "scriptPath": "/Users/admin/actions-runner/maui-runner.sh",
      "autoStart": true
    },
    "giteaActions": {
      "scriptPath": "/Users/admin/gitea-runner/gitea-runner.sh",
      "autoStart": true
    }
  },
  "buildInfo": { /* contents of build-info.json */ }
}
```

## Comparison with GitHub Actions

Like GitHub's hosted runners, our manifests provide:
- ✅ Complete software inventory
- ✅ Version information for all tools
- ✅ Environment variable documentation
- ✅ Machine-readable JSON format
- ✅ Build date and base image tracking

Unlike GitHub's runners:
- Our manifests are generated inside the VM (not in a separate repository)
- We provide both markdown and JSON formats
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
