#!/bin/bash
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ADDITIONAL_XCODES="$1"

if [ -n "$ADDITIONAL_XCODES" ]; then
  echo "Installing additional Xcode versions: $ADDITIONAL_XCODES"
  echo "Note: Some Xcode versions may require Apple ID credentials and will be skipped if not available"

  # Convert comma-separated list to space-separated
  XCODE_LIST=$(echo "$ADDITIONAL_XCODES" | tr ',' ' ')

  for version in $XCODE_LIST; do
    echo "Installing Xcode $version..."
    # Try to install, but don't fail if it requires Apple ID
    if xcodes install $version --no-superuser --experimental-unxip 2>&1 | tee /tmp/xcode-install.log; then
      echo "Successfully installed Xcode $version"
    else
      if grep -q "Apple ID" /tmp/xcode-install.log; then
        echo "Info: Xcode $version requires Apple ID authentication and was skipped"
      else
        echo "Warning: Failed to install Xcode $version"
      fi
    fi
  done

  echo "Additional Xcode installations completed"
  echo "Installed Xcode versions:"
  xcodes installed
else
  echo "No additional Xcode versions to install"
fi
