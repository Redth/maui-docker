#!/usr/bin/bash

INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}

echo "init.sh checking for scripts..."

# Check for and execute initialization scripts if they exist
if [ -f "$INIT_BASH_SCRIPT" ]; then
  echo "Found initialization script at $INIT_BASH_SCRIPT, executing..."
  /usr/bin/bash "$INIT_BASH_SCRIPT"
  echo "Initialization script executed successfully."
fi

if [ -f "$INIT_PWSH_SCRIPT" ]; then
  echo "Found initialization script at $INIT_PWSH_SCRIPT, executing..."
  /usr/bin/pwsh "$INIT_PWSH_SCRIPT"
  echo "Initialization script executed successfully."
fi

echo "init.sh script executed successfully."