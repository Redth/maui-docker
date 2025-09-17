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
  default     = "maui-base-sequoia"
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

source "tart" "maui" {
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
  sources = ["source.tart.maui"]

  # Copy provisioning module to VM
  provisioner "file" {
    source      = "../MauiProvisioning"
    destination = "/tmp/MauiProvisioning"
  }

  # Copy common functions
  provisioner "file" {
    source      = "../../common-functions.ps1"
    destination = "/tmp/common-functions.ps1"
  }

  # Install xcodes for Xcode management
  provisioner "shell" {
    inline = [
      "echo 'Installing xcodes for Xcode management...'",
      "brew install xcodes",
      "echo 'xcodes installed successfully'"
    ]
  }

  # Install Xcode
  provisioner "shell" {
    inline = [
      "echo 'Installing Xcode ${var.xcode_version}...'",
      "# This may take a long time",
      "xcodes install ${var.xcode_version} --experimental-unxip",
      "# Select the installed Xcode",
      "sudo xcode-select -s /Applications/Xcode-${var.xcode_version}.app",
      "# Accept license",
      "sudo xcodebuild -license accept",
      "echo 'Xcode ${var.xcode_version} installed and configured'"
    ]
    timeout = "60m"
  }

  # Run MAUI provisioning
  provisioner "shell" {
    inline = [
      "echo 'Running MAUI provisioning...'",
      "cd /tmp",
      "pwsh -c 'Import-Module ./MauiProvisioning/MauiProvisioning.psd1 -Force; Invoke-MauiProvisioning -DotnetChannel ${var.dotnet_channel}'",
      "echo 'MAUI provisioning completed'"
    ]
    timeout = "30m"
  }

  # Install additional development tools
  provisioner "shell" {
    inline = [
      "echo 'Installing additional development tools...'",
      "brew install --cask visual-studio-code",
      "brew install --cask postman",
      "brew install --cask github-desktop",
      "brew install tree htop",
      "echo 'Additional tools installed'"
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

  # Install .NET MAUI project templates
  provisioner "shell" {
    inline = [
      "echo 'Installing .NET MAUI project templates...'",
      "export PATH=\"$HOME/.dotnet:$PATH\"",
      "dotnet new install Microsoft.Maui.ProjectTemplates",
      "# Verify installation",
      "dotnet new list | grep -i maui",
      "echo 'MAUI project templates installed'"
    ]
  }

  # System optimization for development
  provisioner "shell" {
    inline = [
      "echo 'Optimizing system for development...'",
      "# Increase file watchers for development tools",
      "echo 'kern.maxfiles=65536' | sudo tee -a /etc/sysctl.conf",
      "echo 'kern.maxfilesperproc=32768' | sudo tee -a /etc/sysctl.conf",
      "# Configure simulator settings",
      "defaults write com.apple.iphonesimulator AllowFullscreenMode -bool YES",
      "# Clean up",
      "brew cleanup",
      "sudo rm -rf /tmp/*",
      "echo 'System optimization completed'"
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
      "    \"node\": \"$(node --version 2>/dev/null || echo 'not installed')\"",
      "  },",
      "  \"workloads\": $(dotnet workload list --machine-readable 2>/dev/null || echo '[]')",
      "}",
      "EOF",
      "sudo mv /tmp/build-info.json /usr/local/share/build-info.json",
      "echo 'Build information saved'"
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
      "echo '  - Development utilities'",
      "echo ''",
      "echo 'To run: tart run ${var.image_name}'",
      "echo 'To run with project: tart run ${var.image_name} --dir project:/path/to/your/project'"
    ]
  }
}