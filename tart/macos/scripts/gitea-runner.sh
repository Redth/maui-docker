#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[gitea-runner] $*"
}

# Load environment variables from .env file if mounted
ENV_FILE="/Volumes/My Shared Files/config/.env"
if [[ -f "${ENV_FILE}" ]]; then
  log "Loading environment variables from ${ENV_FILE}"
  set +u  # Temporarily allow unset variables
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Export KEY=VALUE format
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      # Remove surrounding quotes
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"
      export "${key}=${value}"
    fi
  done < "${ENV_FILE}"
  set -u  # Re-enable unset variable check
  log "Environment variables loaded from .env file"
fi

GITEA_INSTANCE_URL=${GITEA_INSTANCE_URL:-""}
GITEA_RUNNER_TOKEN=${GITEA_RUNNER_TOKEN:-""}
GITEA_RUNNER_NAME=${GITEA_RUNNER_NAME:-""}

INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}

RUNNER_ROOT=${GITEA_RUNNER_ROOT:-"/Users/admin/gitea-runner"}
ACT_RUNNER_BIN="${RUNNER_ROOT}/act_runner"
CONFIG_FILE="${RUNNER_ROOT}/.runner"

if [[ ! -d "${RUNNER_ROOT}" ]]; then
  log "Runner root '${RUNNER_ROOT}' not found. Skipping Gitea Actions runner startup."
  exit 0
fi

if [[ ! -f "${ACT_RUNNER_BIN}" ]]; then
  log "act_runner binary not found at '${ACT_RUNNER_BIN}'. Skipping Gitea Actions runner startup."
  exit 0
fi

# Execute optional initialization hooks if present
if [[ -n "${INIT_BASH_SCRIPT}" && -f "${INIT_BASH_SCRIPT}" ]]; then
  log "Executing init bash script '${INIT_BASH_SCRIPT}'"
  /bin/bash "${INIT_BASH_SCRIPT}"
fi

if [[ -n "${INIT_PWSH_SCRIPT}" && -f "${INIT_PWSH_SCRIPT}" ]]; then
  log "Executing init pwsh script '${INIT_PWSH_SCRIPT}'"
  pwsh "${INIT_PWSH_SCRIPT}"
fi

log "GITEA_INSTANCE_URL='${GITEA_INSTANCE_URL}'"

# Bail out quietly if required credentials are not provided
if [[ -z "${GITEA_INSTANCE_URL}" || -z "${GITEA_RUNNER_TOKEN}" ]]; then
  log "Required environment variables not supplied (GITEA_INSTANCE_URL and GITEA_RUNNER_TOKEN). Skipping runner configuration."
  exit 0
fi

cd "${RUNNER_ROOT}"

# Generate runner name if not provided
if [[ -n "${GITEA_RUNNER_NAME}" ]]; then
  RUNNER_NAME_VALUE="${GITEA_RUNNER_NAME}"
else
  NAME_PREFIX=${GITEA_RUNNER_NAME_PREFIX:-gitea-runner}
  RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:-"true"}

  if [[ "${RANDOM_RUNNER_SUFFIX}" == "true" ]]; then
    RAND_SUFFIX=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 13)
    RUNNER_NAME_VALUE="${NAME_PREFIX}-${RAND_SUFFIX}"
  else
    if [[ -s /etc/hostname ]]; then
      HOST_NAME=$(cat /etc/hostname)
    else
      HOST_NAME=$(hostname || echo "macos")
    fi
    RUNNER_NAME_VALUE="${NAME_PREFIX}-${HOST_NAME}"
  fi
fi

RUNNER_LABELS=${GITEA_RUNNER_LABELS:-"macos,maui,arm64"}

# Register the runner if not already configured
if [[ ! -f "${CONFIG_FILE}" ]]; then
  log "Registering runner '${RUNNER_NAME_VALUE}' with Gitea instance at '${GITEA_INSTANCE_URL}'"

  REGISTER_ARGS=(
    "--instance" "${GITEA_INSTANCE_URL}"
    "--token" "${GITEA_RUNNER_TOKEN}"
    "--name" "${RUNNER_NAME_VALUE}"
    "--labels" "${RUNNER_LABELS}"
  )

  if [[ -n "${GITEA_RUNNER_NO_INTERACTIVE:-}" ]]; then
    REGISTER_ARGS+=("--no-interactive")
  fi

  "${ACT_RUNNER_BIN}" register "${REGISTER_ARGS[@]}"
else
  log "Runner already configured (${CONFIG_FILE} exists)"
fi

cleanup() {
  log "Shutting down runner"
  # Gitea runner doesn't have a built-in removal command in the same way
  # The runner will just stop and can be removed from Gitea UI if needed
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

log "Starting Gitea Actions runner daemon"
"${ACT_RUNNER_BIN}" daemon
