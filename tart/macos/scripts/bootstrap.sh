#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[bootstrap] $*"
  logger -t "maui-bootstrap" "$*"
}

log "Starting MAUI VM bootstrap initialization"

# Standard location for user-provided configuration
CONFIG_DIR="/Volumes/My Shared Files/config"
ENV_FILE="${CONFIG_DIR}/.env"
INIT_SCRIPT="${CONFIG_DIR}/init.sh"

# Check if .env file exists (runner scripts will load it themselves)
if [[ -f "${ENV_FILE}" ]]; then
  log "Found .env file at ${ENV_FILE}"
  log "Runner scripts will load environment variables from this file"
else
  log "No .env file found at ${ENV_FILE}"
  log "To configure runners, mount a directory with .env file:"
  log "  tart run <image> --dir config:/path/to/folder/with/.env"
fi

# Run custom initialization script if provided
if [[ -f "${INIT_SCRIPT}" ]]; then
  log "Found custom init script at ${INIT_SCRIPT}"
  log "Executing custom initialization script"

  chmod +x "${INIT_SCRIPT}"

  if /bin/bash "${INIT_SCRIPT}"; then
    log "Custom init script completed successfully"
  else
    log "WARNING: Custom init script exited with error code $?"
  fi
else
  log "No custom init script found at ${INIT_SCRIPT}"
fi

log "Bootstrap initialization complete"

# Manually bootstrap runner LaunchAgents so they start in user context
# These agents should NOT have RunAtLoad=true - they're bootstrapped on-demand by this script
GITHUB_RUNNER_PLIST="${HOME}/Library/LaunchAgents/com.github.actions.runner.plist"
GITEA_RUNNER_PLIST="${HOME}/Library/LaunchAgents/com.gitea.actions.runner.plist"

# Get the user's UID for domain specification
USER_UID=$(id -u)

if [[ -f "${GITHUB_RUNNER_PLIST}" ]]; then
  log "Bootstrapping GitHub Actions runner LaunchAgent"
  # Use bootstrap instead of deprecated load command
  # Bootstrap into user domain (gui/UID) to ensure it runs in user context
  if launchctl bootstrap "gui/${USER_UID}" "${GITHUB_RUNNER_PLIST}" 2>/dev/null; then
    log "GitHub runner LaunchAgent bootstrapped successfully"
  else
    # Agent might already be bootstrapped, try to kickstart it
    if launchctl kickstart -k "gui/${USER_UID}/com.github.actions.runner" 2>/dev/null; then
      log "GitHub runner LaunchAgent was already bootstrapped, restarted it"
    else
      log "GitHub runner LaunchAgent already running or configuration missing"
    fi
  fi
fi

if [[ -f "${GITEA_RUNNER_PLIST}" ]]; then
  log "Bootstrapping Gitea Actions runner LaunchAgent"
  # Use bootstrap instead of deprecated load command
  # Bootstrap into user domain (gui/UID) to ensure it runs in user context
  if launchctl bootstrap "gui/${USER_UID}" "${GITEA_RUNNER_PLIST}" 2>/dev/null; then
    log "Gitea runner LaunchAgent bootstrapped successfully"
  else
    # Agent might already be bootstrapped, try to kickstart it
    if launchctl kickstart -k "gui/${USER_UID}/com.gitea.actions.runner" 2>/dev/null; then
      log "Gitea runner LaunchAgent was already bootstrapped, restarted it"
    else
      log "Gitea runner LaunchAgent already running or configuration missing"
    fi
  fi
fi

log "Runners started (if configured)"

exit 0
