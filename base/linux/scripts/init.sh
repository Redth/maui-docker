#!/usr/bin/bash

# Base initialization script for MAUI development environment
echo "MAUI Base Image - Linux"
echo "=======================" 

# Check for and execute initialization scripts if they exist
INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}

if [ -f "$INIT_BASH_SCRIPT" ]; then
  echo "Found custom initialization script at $INIT_BASH_SCRIPT, executing..."
  /usr/bin/bash "$INIT_BASH_SCRIPT"
  echo "Custom initialization script executed successfully."
fi

if [ -f "$INIT_PWSH_SCRIPT" ]; then
  echo "Found custom initialization script at $INIT_PWSH_SCRIPT, executing..."
  /usr/bin/pwsh "$INIT_PWSH_SCRIPT"
  echo "Custom initialization script executed successfully."
fi

echo "Base initialization complete."
echo "This is a MAUI development base image with .NET $DOTNET_VERSION, Android SDK, and Java $JDK_MAJOR_VERSION"
echo "You can now run your MAUI Android development tasks."
