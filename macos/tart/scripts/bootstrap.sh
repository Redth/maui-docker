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

# Read .env file and set environment variables via launchctl
if [[ -f "${ENV_FILE}" ]]; then
  log "Found .env file at ${ENV_FILE}, loading environment variables"

  # Read each line and set as environment variable
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse KEY=VALUE format
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Remove surrounding quotes if present
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"

      log "Setting environment variable: ${key}"
      launchctl setenv "${key}" "${value}"
    fi
  done < "${ENV_FILE}"

  log "Environment variables loaded successfully"
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
log "Runners will now attempt to start based on configured environment variables"

exit 0
