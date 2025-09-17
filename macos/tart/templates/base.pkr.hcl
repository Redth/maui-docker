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
  default     = "maui-base-sequoia"
}

variable "base_image" {
  type        = string
  description = "Base Tart image to build from"
  default     = "ghcr.io/cirruslabs/macos-sequoia-base:latest"
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

source "tart" "base" {
  vm_base_name = var.base_image
  vm_name      = var.image_name
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  disk_size_gb = 100
  ssh_password = var.ssh_password
  ssh_timeout  = "120s"
  ssh_username = var.ssh_username
  boot_command = []
}

build {
  sources = ["source.tart.base"]

  # Wait for system to be ready
  provisioner "shell" {
    inline = [
      "echo 'Waiting for system to be ready...'",
      "while ! system_profiler SPSoftwareDataType; do sleep 5; done"
    ]
  }

  # Update system and install essential tools
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo softwareupdate -i -a --no-restart || true",
      "echo 'Installing Command Line Tools...'",
      "xcode-select --install || true",
      "echo 'Waiting for Command Line Tools installation...'",
      "while ! xcode-select -p >/dev/null 2>&1; do sleep 10; done"
    ]
  }

  # Configure Homebrew
  provisioner "shell" {
    inline = [
      "echo 'Configuring Homebrew...'",
      "if ! command -v brew >/dev/null 2>&1; then",
      "  echo 'Installing Homebrew...'",
      "  /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      "fi",
      "echo 'Updating Homebrew...'",
      "brew update",
      "brew upgrade"
    ]
  }

  # Install essential development tools
  provisioner "shell" {
    inline = [
      "echo 'Installing essential development tools...'",
      "brew install git curl wget",
      "brew install powershell",
      "brew install jq yq",
      "echo 'Development tools installed successfully'"
    ]
  }

  # Configure SSH for automation
  provisioner "shell" {
    inline = [
      "echo 'Configuring SSH...'",
      "sudo systemsetup -setremotelogin on",
      "sudo dscl . -create /Users/${var.ssh_username}",
      "sudo dscl . -create /Users/${var.ssh_username} UserShell /bin/bash",
      "sudo dscl . -create /Users/${var.ssh_username} RealName 'Admin User'",
      "sudo dscl . -create /Users/${var.ssh_username} UniqueID 501",
      "sudo dscl . -create /Users/${var.ssh_username} PrimaryGroupID 80",
      "sudo dscl . -create /Users/${var.ssh_username} NFSHomeDirectory /Users/${var.ssh_username}",
      "sudo dscl . -passwd /Users/${var.ssh_username} ${var.ssh_password}",
      "sudo dscl . -append /Groups/admin GroupMembership ${var.ssh_username}",
      "sudo createhomedir -c -u ${var.ssh_username} || true"
    ]
  }

  # System optimization and cleanup
  provisioner "shell" {
    inline = [
      "echo 'Optimizing system settings...'",
      "# Disable automatic software updates",
      "sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false",
      "sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false",
      "# Disable Spotlight indexing for faster builds",
      "sudo mdutil -a -i off",
      "# Clean up",
      "brew cleanup",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "echo 'System optimization completed'"
    ]
  }

  # Create build info file
  provisioner "shell" {
    inline = [
      "echo 'Creating build information...'",
      "cat > /tmp/build-info.json << EOF",
      "{",
      "  \"image_type\": \"base\",",
      "  \"macos_version\": \"${var.macos_version}\",",
      "  \"build_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",",
      "  \"tools\": {",
      "    \"homebrew\": \"$(brew --version | head -1)\",",
      "    \"git\": \"$(git --version)\",",
      "    \"powershell\": \"$(pwsh --version)\"",
      "  }",
      "}",
      "EOF",
      "sudo mv /tmp/build-info.json /usr/local/share/build-info.json",
      "echo 'Build information saved to /usr/local/share/build-info.json'"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Base image build completed: ${var.image_name}'",
      "echo 'Image size: '",
      "tart get ${var.image_name} | grep 'Disk size'",
      "echo 'To run: tart run ${var.image_name}'"
    ]
  }
}