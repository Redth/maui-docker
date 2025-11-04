packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "image_name" {
  type        = string
  description = "Name for the output image"
  default     = "maui-dev-sequoia"
}

variable "base_image" {
  type        = string
  description = "Base Tart image to build from"
  default     = "ghcr.io/cirruslabs/macos-sequoia-xcode:16.4"
}

variable "macos_version" {
  type        = string
  description = "macOS version"
  default     = "sequoia"
}

variable "dotnet_channel" {
  type        = string
  description = ".NET channel to install"
  default     = "10.0"
}

variable "workload_set_version" {
  type        = string
  description = "Specific workload set version (e.g., 10.0.100-rc.1.24557.12). Leave empty for auto-detect."
  default     = ""
}

variable "base_xcode_version" {
  type        = string
  description = "Base Xcode version from upstream image (use @sha256:... for pinning to specific digest)"
  default     = "@sha256:49c83cf0989d5c3039b8f1a5c543aa25b2cd920784fdaf30be22e18e4edeaa95"
}

variable "additional_xcode_versions" {
  type        = string
  description = "Comma-separated list of additional Xcode versions to install"
  default     = ""
}

variable "cpu_count" {
  type        = number
  description = "Number of CPUs for the VM"
  default     = 4
}

variable "memory_gb" {
  type        = number
  description = "Memory in GB for the VM"
  default     = 8
}

variable "ssh_username" {
  type        = string
  description = "SSH username"
  default     = "admin"
}

variable "ssh_password" {
  type        = string
  description = "SSH password"
  default     = "admin"
}

variable "registry" {
  type        = string
  description = "Docker registry for images"
  default     = ""
}

variable "build_settings" {
  type        = object({})
  description = "Build settings configuration"
  default     = {}
}

variable "ci_tools" {
  type        = object({})
  description = "CI tools configuration"
  default     = {}
}

variable "development_tools" {
  type        = object({})
  description = "Development tools configuration"
  default     = {}
}

variable "optimization" {
  type        = object({})
  description = "VM optimization settings"
  default     = {}
}

source "tart-cli" "maui" {
  vm_base_name = var.base_image
  vm_name      = var.image_name
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  disk_size_gb = 120
  ssh_password = var.ssh_password
  ssh_timeout  = "120s"
  ssh_username = var.ssh_username
}

build {
  sources = ["source.tart-cli.maui"]

  # Copy provisioning module to VM
  provisioner "file" {
    source      = "../../../provisioning/MauiProvisioning"
    destination = "/tmp/MauiProvisioning"
  }

  provisioner "file" {
    source      = "../scripts/github-runner.sh"
    destination = "/tmp/github-runner.sh"
  }

  # Copy common functions
  provisioner "file" {
    source      = "../../../common-functions.ps1"
    destination = "/tmp/common-functions.ps1"
  }

  # Install PowerShell and base tools
  provisioner "shell" {
    inline = [
      "# Install Homebrew if not present",
      "/bin/bash -c \"$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" || echo 'Homebrew already installed'",
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "echo 'Installing PowerShell...'",
      "# Install PowerShell",
      "brew install --cask powershell",
      "echo 'PowerShell installed'",
      "echo 'Installing Node...'",
      "# Install Node",
      "brew install node",
      "echo 'Node installed'",
      "echo 'Installing Appium...'",
      "# Install Appium",
      "brew install appium",
      "echo 'Appium installed'",
      "echo 'Installing Appium Drivers...'",
      "# Install Appium Drivers (need full PATH for npm to find sh)",
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "appium driver install uiautomator2 || echo 'Warning: uiautomator2 driver installation failed'",
      "appium driver install xcuitest || echo 'Warning: xcuitest driver installation failed'",
      "appium driver install mac2 || echo 'Warning: mac2 driver installation failed'",
      "echo 'Appium Drivers installation completed'",
      "echo 'Installing xcodes CLI for Xcode management...'",
      "# Install xcodes and aria2c for faster downloads",
      "brew install xcodesorg/made/xcodes aria2",
      "echo 'xcodes CLI installed'",
    ]
    timeout = "20m"
  }

  # Copy Xcode installation script
  provisioner "file" {
    source      = "../scripts/install-additional-xcodes.sh"
    destination = "/tmp/install-additional-xcodes.sh"
  }

  # Install additional Xcode versions
  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install-additional-xcodes.sh",
      "/tmp/install-additional-xcodes.sh '${var.additional_xcode_versions}'",
    ]
    timeout = "60m"
  }

  # Run MAUI provisioning
  provisioner "shell" {
    inline = [
      "echo 'Running MAUI provisioning...'",
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "cd /tmp",
      "# Create the directory structure expected by the provisioning module",
      "mkdir -p /tmp/provisioning",
      "cp /tmp/common-functions.ps1 /tmp/provisioning/common-functions.ps1",
      "# Create symlink structure to match expected relative paths",
      "mkdir -p /tmp/provisioning/MauiProvisioning",
      "cp -r /tmp/MauiProvisioning/* /tmp/provisioning/MauiProvisioning/",
      "cd /tmp/provisioning",
      "echo 'Starting MAUI provisioning module...'",
      "WORKLOAD_SET_VERSION='${var.workload_set_version}'",
      "if [ -n \"$${WORKLOAD_SET_VERSION}\" ]; then",
      "  echo \"Using specific workload set version: $${WORKLOAD_SET_VERSION}\"",
      "  if pwsh -c \"Import-Module ./MauiProvisioning/MauiProvisioning.psd1 -Force; Invoke-MauiProvisioning -DotnetChannel ${var.dotnet_channel} -WorkloadSetVersion '$${WORKLOAD_SET_VERSION}'\"; then",
      "    echo 'MAUI provisioning completed successfully'",
      "  else",
      "    echo 'ERROR: MAUI provisioning failed'",
      "    exit 1",
      "  fi",
      "else",
      "  echo \"No workload set version specified - will auto-detect latest\"",
      "  if pwsh -c 'Import-Module ./MauiProvisioning/MauiProvisioning.psd1 -Force; Invoke-MauiProvisioning -DotnetChannel ${var.dotnet_channel}'; then",
      "    echo 'MAUI provisioning completed successfully'",
      "  else",
      "    echo 'ERROR: MAUI provisioning failed'",
      "    exit 1",
      "  fi",
      "fi",
      "# Verify dotnet was installed",
      "if [ -f /Users/admin/.dotnet/dotnet ] || [ -f /usr/local/share/dotnet/dotnet ]; then",
      "  echo 'Dotnet installation verified'",
      "else",
      "  echo 'WARNING: dotnet binary not found after provisioning'",
      "  ls -la /Users/admin/.dotnet/ 2>/dev/null || echo '/Users/admin/.dotnet does not exist'",
      "  ls -la /usr/local/share/dotnet/ 2>/dev/null || echo '/usr/local/share/dotnet does not exist'",
      "fi"
    ]
    timeout = "30m"
  }

  # Install GitHub Actions runner helper script
  provisioner "shell" {
    inline = [
      "export PATH=\"/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "echo 'Installing GitHub Actions runner helper script...'",
      "mkdir -p /Users/admin/actions-runner",
      "mv /tmp/github-runner.sh /Users/admin/actions-runner/maui-runner.sh",
      "chown admin:staff /Users/admin/actions-runner/maui-runner.sh",
      "chmod +x /Users/admin/actions-runner/maui-runner.sh",
      "echo 'Runner helper script installed at /Users/admin/actions-runner/maui-runner.sh'"
    ]
  }

  # Copy Gitea Actions runner helper script
  provisioner "file" {
    source      = "../scripts/gitea-runner.sh"
    destination = "/tmp/gitea-runner.sh"
  }

  # Install Gitea Actions runner
  provisioner "shell" {
    inline = [
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "echo 'Installing Gitea Actions runner...'",
      "mkdir -p /Users/admin/gitea-runner",
      "cd /Users/admin/gitea-runner",
      "# Detect architecture",
      "ARCH=$$(uname -m)",
      "if [ \"$$ARCH\" = \"arm64\" ]; then",
      "  DOWNLOAD_ARCH=\"arm64\"",
      "else",
      "  DOWNLOAD_ARCH=\"amd64\"",
      "fi",
      "echo \"Detected architecture: $$ARCH (downloading $$DOWNLOAD_ARCH)\"",
      "# Get latest release version",
      "LATEST_VERSION=$$(curl -fsSL https://gitea.com/api/v1/repos/gitea/act_runner/releases | jq -r '.[0].tag_name')",
      "echo \"Latest act_runner version: $$LATEST_VERSION\"",
      "# Download act_runner binary",
      "DOWNLOAD_URL=\"https://dl.gitea.com/act_runner/$$LATEST_VERSION/act_runner-$$LATEST_VERSION-darwin-$$DOWNLOAD_ARCH\"",
      "echo \"Downloading from: $$DOWNLOAD_URL\"",
      "curl -fsSL \"$$DOWNLOAD_URL\" -o act_runner",
      "chmod +x act_runner",
      "# Move helper script into place",
      "mv /tmp/gitea-runner.sh /Users/admin/gitea-runner/gitea-runner.sh",
      "chmod +x /Users/admin/gitea-runner/gitea-runner.sh",
      "chown -R admin:staff /Users/admin/gitea-runner",
      "echo 'Gitea Actions runner installed'",
      "echo 'Runner binary: /Users/admin/gitea-runner/act_runner'",
      "echo 'Runner helper script: /Users/admin/gitea-runner/gitea-runner.sh'"
    ]
    timeout = "10m"
  }

  # Copy shell profile setup script
  provisioner "file" {
    source      = "../scripts/setup-shell-profiles.sh"
    destination = "/tmp/setup-shell-profiles.sh"
  }

  # Configure development environment
  provisioner "shell" {
    inline = [
      "export PATH=\"/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "echo 'Configuring development environment...'",
      "# Create common development directories",
      "mkdir -p ~/Development/Projects",
      "mkdir -p ~/Development/Tools",
      "# Configure git (user will need to set their own credentials)",
      "git config --global init.defaultBranch main",
      "git config --global core.autocrlf input",
      "# Set up shell profiles",
      "chmod +x /tmp/setup-shell-profiles.sh",
      "/tmp/setup-shell-profiles.sh",
      "echo 'Development environment configured'"
    ]
  }

  # Install useful dotnet tools
  provisioner "shell" {
    inline = [
      "export PATH=\"/Users/admin/.dotnet:/Users/admin/.dotnet/tools:/usr/local/share/dotnet:/usr/bin:/bin:$$PATH\"",
      "export DOTNET_ROOT=\"/Users/admin/.dotnet\"",
      "echo 'Installing dotnet tools...'",
      "echo \"PATH: $$PATH\"",
      "echo \"Checking for dotnet...\"",
      "which dotnet || echo 'dotnet not found in PATH'",
      "if command -v dotnet >/dev/null 2>&1; then",
      "  dotnet --version",
      "  dotnet tool install -g AndroidSdk.Tool || echo 'Warning: AndroidSdk.Tool installation failed'",
      "  dotnet tool install -g AppleDev.Tools || echo 'Warning: AppleDev.Tools installation failed'",
      "  echo 'Installed dotnet tools'",
      "else",
      "  echo 'ERROR: dotnet command not found. MAUI provisioning may have failed.'",
      "  exit 1",
      "fi"
    ]
  }

  # Create build info file
  provisioner "shell" {
    inline = [
      "export PATH=\"/Users/admin/.dotnet:/Users/admin/.dotnet/tools:/usr/local/share/dotnet:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "export DOTNET_ROOT=\"/Users/admin/.dotnet\"",
      "echo 'Creating build information...'",
      "cat > /tmp/build-info.json << EOF",
      "{",
      "  \"image_type\": \"maui\",",
      "  \"macos_version\": \"${var.macos_version}\",",
      "  \"build_date\": \"$$(date -u +%Y-%m-%dT%H:%M:%SZ)\",",
      "  \"dotnet_channel\": \"${var.dotnet_channel}\",",
      "  \"base_xcode_version\": \"${var.base_xcode_version}\",",
      "  \"additional_xcode_versions\": \"${var.additional_xcode_versions}\",",
      "  \"tools\": {",
      "    \"dotnet\": \"$$(dotnet --version)\",",
      "    \"xcode\": \"$$(xcodebuild -version | head -1)\",",
      "    \"git\": \"$$(git --version)\",",
      "    \"node\": \"$$(node --version 2>/dev/null || echo 'not installed')\",",
      "    \"npm\": \"$$(npm --version 2>/dev/null || echo 'not installed')\",",
      "    \"gh\": \"$$(gh --version 2>/dev/null | head -1 || echo 'not installed')\",",
      "    \"fastlane\": \"$$(fastlane --version 2>/dev/null || echo 'not installed')\",",
      "    \"act_runner\": \"$$(/Users/admin/gitea-runner/act_runner --version 2>/dev/null || echo 'not installed')\"",
      "  },",
      "  \"capabilities\": [",
      "    \"ios-build\",",
      "    \"android-build\",",
      "    \"maui-build\",",
      "    \"ui-testing\",",
      "    \"github-actions\",",
      "    \"gitea-actions\",",
      "    \"automated-testing\",",
      "    \"multiple-xcode-versions\"",
      "  ],",
      "  \"workloads\": $$(dotnet workload list --machine-readable 2>/dev/null || echo '[]')",
      "}",
      "EOF",
      "sudo mv /tmp/build-info.json /usr/local/share/build-info.json",
      "echo 'Build information saved'"
    ]
  }

  # Final cleanup and optimization
  provisioner "shell" {
    inline = [
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "echo 'Performing final cleanup and optimization...'",
      "brew cleanup",
      "sudo rm -rf /var/tmp/*",
      "sudo rm -rf /var/log/*",
      "rm -rf ~/Library/Developer/Xcode/DerivedData/*",
      "echo 'Cleanup completed'"
    ]
  }

  # Final verification
  provisioner "shell" {
    inline = [
      "export PATH=\"/Users/admin/.dotnet:/Users/admin/.dotnet/tools:/usr/local/share/dotnet:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$$PATH\"",
      "export DOTNET_ROOT=\"/Users/admin/.dotnet\"",
      "echo 'Running final verification...'",
      "echo 'Dotnet version:'",
      "dotnet --version",
      "echo 'Installed workloads:'",
      "dotnet workload list",
      "echo 'Default Xcode version:'",
      "xcodebuild -version",
      "echo 'All installed Xcode versions:'",
      "xcodes installed 2>/dev/null || echo 'xcodes CLI not available'",
      "echo 'Available simulators:'",
      "xcrun simctl list devices available | head -10",
      "echo 'Android SDK:'",
      "ls -la ~/Library/Android/sdk/platforms/ 2>/dev/null || echo 'Android SDK not found'",
      "echo 'Verification completed successfully'"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'MAUI development image build completed: ${var.image_name}'",
      "echo 'Image includes:'",
      "echo '  - .NET ${var.dotnet_channel} SDK'",
      "echo '  - MAUI workloads and templates'",
      "echo '  - Xcode ${var.base_xcode_version} (base)'",
      "if [ -n '${var.additional_xcode_versions}' ]; then echo '  - Additional Xcode versions: ${var.additional_xcode_versions}'; fi",
      "echo '  - Android SDK and tools'",
      "echo '  - Visual Studio Code'",
      "echo '  - Development utilities and CI helpers'",
      "echo ''",
      "echo 'Xcode Management:'",
      "echo '  - List versions: xcodes installed'",
      "echo '  - Switch version: sudo xcodes select <version>'",
      "echo '  - Current version: xcodebuild -version'",
      "echo ''",
      "echo 'CI Runner Support:'",
      "echo '  GitHub Actions: /Users/admin/actions-runner/maui-runner.sh'",
      "echo '    Set GITHUB_ORG/GITHUB_TOKEN (and optional runner vars) before launching to auto-register'",
      "echo '  Gitea Actions: /Users/admin/gitea-runner/gitea-runner.sh'",
      "echo '    Set GITEA_INSTANCE_URL/GITEA_RUNNER_TOKEN before launching to auto-register'",
      "echo ''",
      "echo 'To run: tart run ${var.image_name}'",
      "echo 'To run with project: tart run ${var.image_name} --dir project:/path/to/your/project'"
    ]
  }
}
