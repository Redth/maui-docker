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
  default     = "maui-ci-sequoia"
}

variable "base_image" {
  type        = string
  description = "Base Tart image to build from"
  default     = "maui-dev-sequoia"
}

variable "macos_version" {
  type        = string
  description = "macOS version"
  default     = "sequoia"
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

source "tart" "ci" {
  vm_base_name = var.base_image
  vm_name      = var.image_name
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  disk_size_gb = 100
  ssh_password = var.ssh_password
  ssh_timeout  = "120s"
  ssh_username = var.ssh_username
}

build {
  sources = ["source.tart.ci"]

  # Install CI/CD tools
  provisioner "shell" {
    inline = [
      "echo 'Installing CI/CD tools...'",
      "brew install gh",
      "brew install --cask docker",
      "brew install cmake",
      "brew install ninja",
      "brew install fastlane",
      "echo 'CI/CD tools installed'"
    ]
  }

  # Install testing frameworks and tools
  provisioner "shell" {
    inline = [
      "echo 'Installing testing tools...'",
      "export PATH=\"$HOME/.dotnet:$PATH\"",
      "# Install global dotnet tools for testing",
      "dotnet tool install -g dotnet-reportgenerator-globaltool",
      "dotnet tool install -g coverlet.console",
      "dotnet tool install -g dotnet-stryker",
      "# Install Appium for UI testing",
      "npm install -g appium",
      "appium driver install uiautomator2",
      "appium driver install xcuitest",
      "echo 'Testing tools installed'"
    ]
  }

  # Configure automated simulator management
  provisioner "shell" {
    inline = [
      "echo 'Configuring simulator management...'",
      "# Create simulator management scripts",
      "mkdir -p ~/bin",
      "cat > ~/bin/prepare-simulators.sh << 'EOF'",
      "#!/bin/bash",
      "# Boot iOS simulator",
      "xcrun simctl boot \"iPhone 15 Pro\" 2>/dev/null || echo \"Simulator already booted or not available\"",
      "# Start Android emulator if available",
      "if [ -d \"$HOME/Library/Android/sdk/emulator\" ]; then",
      "  nohup $HOME/Library/Android/sdk/emulator/emulator @android-35 -no-window -no-audio > /dev/null 2>&1 &",
      "fi",
      "EOF",
      "chmod +x ~/bin/prepare-simulators.sh",
      "echo 'export PATH=\"$HOME/bin:$PATH\"' >> ~/.bash_profile",
      "echo 'export PATH=\"$HOME/bin:$PATH\"' >> ~/.zshrc"
    ]
  }

  # Install GitHub Actions runner (self-hosted)
  provisioner "shell" {
    inline = [
      "echo 'Installing GitHub Actions runner...'",
      "mkdir -p ~/actions-runner",
      "cd ~/actions-runner",
      "# Download latest runner (this URL may need updating)",
      "curl -o actions-runner-osx-arm64.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-osx-arm64-2.311.0.tar.gz",
      "tar xzf actions-runner-osx-arm64.tar.gz",
      "rm actions-runner-osx-arm64.tar.gz",
      "# Make runner executable",
      "chmod +x run.sh",
      "echo 'GitHub Actions runner installed (needs configuration with token)'"
    ]
  }

  # Configure system for CI workloads
  provisioner "shell" {
    inline = [
      "echo 'Configuring system for CI workloads...'",
      "# Disable sleep and screensaver",
      "sudo pmset -a displaysleep 0",
      "sudo pmset -a sleep 0",
      "# Disable automatic updates completely",
      "sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false",
      "sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false",
      "sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false",
      "# Configure maximum file handles",
      "echo 'kern.maxfiles=1048576' | sudo tee -a /etc/sysctl.conf",
      "echo 'kern.maxfilesperproc=524288' | sudo tee -a /etc/sysctl.conf",
      "# Disable crash reporter",
      "defaults write com.apple.CrashReporter DialogType none",
      "echo 'System configured for CI workloads'"
    ]
  }

  # Create CI helper scripts
  provisioner "shell" {
    inline = [
      "echo 'Creating CI helper scripts...'",
      "mkdir -p ~/ci-scripts",
      "# Build script",
      "cat > ~/ci-scripts/build-maui.sh << 'EOF'",
      "#!/bin/bash",
      "set -e",
      "echo \"Starting MAUI build...\"",
      "export PATH=\"$HOME/.dotnet:$HOME/.dotnet/tools:$PATH\"",
      "export DOTNET_ROOT=\"$HOME/.dotnet\"",
      "# Restore dependencies",
      "dotnet restore",
      "# Build for all platforms",
      "dotnet build -c Release",
      "echo \"Build completed successfully\"",
      "EOF",
      "# Test script",
      "cat > ~/ci-scripts/test-maui.sh << 'EOF'",
      "#!/bin/bash",
      "set -e",
      "echo \"Starting MAUI tests...\"",
      "export PATH=\"$HOME/.dotnet:$HOME/.dotnet/tools:$PATH\"",
      "export DOTNET_ROOT=\"$HOME/.dotnet\"",
      "# Run unit tests",
      "dotnet test --logger \"trx;LogFileName=test-results.trx\" --collect:\"XPlat Code Coverage\"",
      "echo \"Tests completed successfully\"",
      "EOF",
      "chmod +x ~/ci-scripts/*.sh",
      "echo 'CI helper scripts created'"
    ]
  }

  # Create build info file
  provisioner "shell" {
    inline = [
      "echo 'Creating build information...'",
      "export PATH=\"$HOME/.dotnet:$PATH\"",
      "cat > /tmp/build-info.json << EOF",
      "{",
      "  \"image_type\": \"ci\",",
      "  \"macos_version\": \"${var.macos_version}\",",
      "  \"build_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",",
      "  \"tools\": {",
      "    \"dotnet\": \"$(dotnet --version)\",",
      "    \"xcode\": \"$(xcodebuild -version | head -1)\",",
      "    \"git\": \"$(git --version)\",",
      "    \"gh\": \"$(gh --version | head -1)\",",
      "    \"fastlane\": \"$(fastlane --version)\",",
      "    \"node\": \"$(node --version)\",",
      "    \"npm\": \"$(npm --version)\"",
      "  },",
      "  \"capabilities\": [",
      "    \"ios-build\",",
      "    \"android-build\",",
      "    \"maui-build\",",
      "    \"ui-testing\",",
      "    \"github-actions\",",
      "    \"automated-testing\"",
      "  ]",
      "}",
      "EOF",
      "sudo mv /tmp/build-info.json /usr/local/share/build-info.json"
    ]
  }

  # Final cleanup and optimization
  provisioner "shell" {
    inline = [
      "echo 'Final cleanup and optimization...'",
      "# Clean caches",
      "brew cleanup",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "# Clear logs",
      "sudo rm -rf /var/log/*",
      "# Clear Xcode derived data",
      "rm -rf ~/Library/Developer/Xcode/DerivedData/*",
      "# Compact disk (if supported)",
      "sudo fstrim -v / 2>/dev/null || echo 'fstrim not available'",
      "echo 'Cleanup completed'"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'CI/CD image build completed: ${var.image_name}'",
      "echo 'Image includes:'",
      "echo '  - Complete MAUI development environment'",
      "echo '  - GitHub CLI and Actions runner'",
      "echo '  - Testing frameworks and tools'",
      "echo '  - Fastlane for mobile app deployment'",
      "echo '  - Appium for UI testing'",
      "echo '  - Optimized for automated builds'",
      "echo ''",
      "echo 'To run: tart run ${var.image_name}'",
      "echo 'For CI usage: tart run ${var.image_name} --dir workspace:/path/to/workspace'",
      "echo ''",
      "echo 'Configure GitHub Actions runner with:'",
      "echo '  cd ~/actions-runner'",
      "echo '  ./config.sh --url <repo-url> --token <token>'"
    ]
  }
}