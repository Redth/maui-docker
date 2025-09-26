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

variable "xcode_version" {
  type        = string
  description = "Xcode version to install"
  default     = "16.4"
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
    source      = "../../provisioning/MauiProvisioning"
    destination = "/tmp/MauiProvisioning"
  }

  provisioner "file" {
    source      = "./scripts/github-runner.sh"
    destination = "/tmp/github-runner.sh"
  }

  # Copy common functions
  provisioner "file" {
    source      = "../../common-functions.ps1"
    destination = "/tmp/common-functions.ps1"
  }

  # Install PowerShell
  provisioner "shell" {
    inline = [
      "# Install Homebrew if not present",
      "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" || echo 'Homebrew already installed'",
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"",
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
      "# Install Appium Drivers",
      "appium driver install uiautomator2",
      "appium driver install xcuitest",
      "appium driver install mac2",
      "echo 'Appium Drivers installed'",
    ]
    timeout = "20m"
  }

  # Run MAUI provisioning
  provisioner "shell" {
    inline = [
      "echo 'Running MAUI provisioning...'",
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"",
      "cd /tmp",
      "# Create the directory structure expected by the provisioning module",
      "mkdir -p /tmp/provisioning",
      "cp /tmp/common-functions.ps1 /tmp/provisioning/common-functions.ps1",
      "# Create symlink structure to match expected relative paths",
      "mkdir -p /tmp/provisioning/MauiProvisioning",
      "cp -r /tmp/MauiProvisioning/* /tmp/provisioning/MauiProvisioning/",
      "cd /tmp/provisioning",
      "pwsh -c 'Import-Module ./MauiProvisioning/MauiProvisioning.psd1 -Force; Invoke-MauiProvisioning -DotnetChannel ${var.dotnet_channel}'",
      "echo 'MAUI provisioning completed'"
    ]
    timeout = "30m"
  }

  # Install GitHub Actions runner helper script
  provisioner "shell" {
    inline = [
      "echo 'Installing GitHub Actions runner helper script...'",
      "mv /tmp/github-runner.sh /Users/admin/actions-runner/maui-runner.sh",
      "chown admin:staff /Users/admin/actions-runner/maui-runner.sh",
      "chmod +x /Users/admin/actions-runner/maui-runner.sh",
      "echo 'Runner helper script installed at /Users/admin/actions-runner/maui-runner.sh'"
    ]
  }

  # Configure development environment
  provisioner "shell" {
    inline = [
      "echo 'Configuring development environment...'",
      "# Create common development directories",
      "mkdir -p ~/Development/Projects",
      "mkdir -p ~/Development/Tools",
      "# Configure git (user will need to set their own credentials)",
      "git config --global init.defaultBranch main",
      "git config --global core.autocrlf input",
      "# Add dotnet tools to PATH permanently",
      "echo 'export PATH=\"$HOME/.dotnet:$HOME/.dotnet/tools:$PATH\"' >> ~/.bash_profile",
      "echo 'export PATH=\"$HOME/.dotnet:$HOME/.dotnet/tools:$PATH\"' >> ~/.zshrc",
      "echo 'export DOTNET_ROOT=\"$HOME/.dotnet\"' >> ~/.bash_profile",
      "echo 'export DOTNET_ROOT=\"$HOME/.dotnet\"' >> ~/.zshrc",
      "echo 'Development environment configured'"
    ]
  }

  # Install useful dotnet tools
  provisioner "shell" {
    inline = [      
      "echo 'Installing dotnet tools...'",
      "export PATH=\"$HOME/.dotnet:$PATH\"",
      "# Install dotnet tools",
      "dotnet tool install -g AndroidSdk.Tool",
      "dotnet tool install -g AppleDev.Tools",
      "echo 'Installed dotnet tools'"
    ]
  }

  # Create build info file
  provisioner "shell" {
    inline = [
      "echo 'Creating build information...'",
      "export PATH=\"$HOME/.dotnet:$PATH\"",
      "cat > /tmp/build-info.json << EOF",
      "{",
      "  \"image_type\": \"maui\",",
      "  \"macos_version\": \"${var.macos_version}\",",
      "  \"build_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",",
      "  \"dotnet_channel\": \"${var.dotnet_channel}\",",
      "  \"xcode_version\": \"${var.xcode_version}\",",
      "  \"tools\": {",
      "    \"dotnet\": \"$(dotnet --version)\",",
      "    \"xcode\": \"$(xcodebuild -version | head -1)\",",
      "    \"git\": \"$(git --version)\",",
      "    \"node\": \"$(node --version 2>/dev/null || echo 'not installed')\",",
      "    \"npm\": \"$(npm --version 2>/dev/null || echo 'not installed')\",",
      "    \"gh\": \"$(gh --version 2>/dev/null | head -1 || echo 'not installed')\",",
      "    \"fastlane\": \"$(fastlane --version 2>/dev/null || echo 'not installed')\"",
      "  },",
      "  \"capabilities\": [",
      "    \"ios-build\",",
      "    \"android-build\",",
      "    \"maui-build\",",
      "    \"ui-testing\",",
      "    \"github-actions\",",
      "    \"automated-testing\"",
      "  ],",
      "  \"workloads\": $(dotnet workload list --machine-readable 2>/dev/null || echo '[]')",
      "}",
      "EOF",
      "sudo mv /tmp/build-info.json /usr/local/share/build-info.json",
      "echo 'Build information saved'"
    ]
  }

  # Final cleanup and optimization
  provisioner "shell" {
    inline = [
      "echo 'Performing final cleanup and optimization...'",
      "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"",
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
      "echo 'Running final verification...'",
      "export PATH=\"$HOME/.dotnet:$PATH\"",
      "echo 'Dotnet version:'",
      "dotnet --version",
      "echo 'Installed workloads:'",
      "dotnet workload list",
      "echo 'Xcode version:'",
      "xcodebuild -version",
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
      "echo '  - Xcode ${var.xcode_version}'",
      "echo '  - Android SDK and tools'",
      "echo '  - Visual Studio Code'",
      "echo '  - Development utilities and CI helpers'",
      "echo ''",
      "echo 'Runner helper script: /Users/admin/actions-runner/maui-runner.sh'",
      "echo '  Set GITHUB_ORG/GITHUB_TOKEN (and optional runner vars) before launching to auto-register'",
      "echo ''",
      "echo 'To run: tart run ${var.image_name}'",
      "echo 'To run with project: tart run ${var.image_name} --dir project:/path/to/your/project'"
    ]
  }
}
