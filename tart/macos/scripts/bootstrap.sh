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

# Manually load runner LaunchAgents so they inherit the environment variables we just set
# These agents should NOT have RunAtLoad=true - they're loaded on-demand by bootstrap
GITHUB_RUNNER_PLIST="${HOME}/Library/LaunchAgents/com.github.actions.runner.plist"
GITEA_RUNNER_PLIST="${HOME}/Library/LaunchAgents/com.gitea.actions.runner.plist"

if [[ -f "${GITHUB_RUNNER_PLIST}" ]]; then
  log "Loading GitHub Actions runner LaunchAgent"
  launchctl load "${GITHUB_RUNNER_PLIST}" 2>/dev/null || log "GitHub runner LaunchAgent already loaded or failed to load"
fi

if [[ -f "${GITEA_RUNNER_PLIST}" ]]; then
  log "Loading Gitea Actions runner LaunchAgent"
  launchctl load "${GITEA_RUNNER_PLIST}" 2>/dev/null || log "Gitea runner LaunchAgent already loaded or failed to load"
fi

log "Runners started (if configured)"

exit 0
