#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "[github-runner] $*"
}

GITHUB_ORG=${GITHUB_ORG:-""}
GITHUB_REPO=${GITHUB_REPO:-""}
GITHUB_TOKEN=${GITHUB_TOKEN:-""}

INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}

RUNNER_ROOT=${RUNNER_ROOT:-"/Users/admin/actions-runner"}
CONFIG_SCRIPT="${RUNNER_ROOT}/config.sh"
RUN_SCRIPT="${RUNNER_ROOT}/run.sh"

if [[ ! -d "${RUNNER_ROOT}" ]]; then
  log "Runner root '${RUNNER_ROOT}' not found. Skipping GitHub Actions runner startup."
  exit 0
fi

if [[ ! -f "${CONFIG_SCRIPT}" || ! -f "${RUN_SCRIPT}" ]]; then
  log "Runner scripts not found in '${RUNNER_ROOT}'. Skipping GitHub Actions runner startup."
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

log "GITHUB_ORG='${GITHUB_ORG}'"
log "GITHUB_REPO='${GITHUB_REPO}'"

# Bail out quietly if required credentials are not provided
if [[ -z "${GITHUB_ORG}" || -z "${GITHUB_TOKEN}" ]]; then
  log "Required environment variables not supplied (GITHUB_ORG and GITHUB_TOKEN). Skipping runner configuration."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log "ERROR: 'jq' is required but not available on PATH."
  exit 1
fi

API_URL=${GITHUB_API_URL:-"https://api.github.com"}
API_URL=${API_URL%%/}
SERVER_URL=${GITHUB_SERVER_URL:-"https://github.com"}
SERVER_URL=${SERVER_URL%%/}

if [[ -n "${GITHUB_REPO}" ]]; then
  RUNNER_URL="${SERVER_URL}/${GITHUB_ORG}/${GITHUB_REPO}"
  REGISTRATION_ENDPOINT="${API_URL}/repos/${GITHUB_ORG}/${GITHUB_REPO}/actions/runners/registration-token"
  log "Registering runner at repository scope"
else
  RUNNER_URL="${SERVER_URL}/${GITHUB_ORG}"
  REGISTRATION_ENDPOINT="${API_URL}/orgs/${GITHUB_ORG}/actions/runners/registration-token"
  log "Registering runner at organization scope"
fi

log "Requesting registration token from '${REGISTRATION_ENDPOINT}'"
REG_TOKEN=$(curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "${REGISTRATION_ENDPOINT}" | jq -r '.token // empty')

if [[ -z "${REG_TOKEN}" ]]; then
  log "ERROR: Failed to retrieve runner registration token."
  exit 1
fi

cd "${RUNNER_ROOT}"

RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:-"true"}

if [[ -n "${RUNNER_NAME:-}" ]]; then
  RUNNER_NAME_VALUE="${RUNNER_NAME}"
else
  NAME_PREFIX=${RUNNER_NAME_PREFIX:-github-runner}
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

RUNNER_WORKDIR=${RUNNER_WORKDIR:-"${RUNNER_ROOT}/_work/${RUNNER_NAME_VALUE}"}
RUNNER_GROUP=${RUNNER_GROUP:-Default}
LABELS=${LABELS:-default}

mkdir -p "${RUNNER_WORKDIR}"

CONFIG_ARGS=(
  "--url" "${RUNNER_URL}"
  "--token" "${REG_TOKEN}"
  "--name" "${RUNNER_NAME_VALUE}"
  "--work" "${RUNNER_WORKDIR}"
  "--labels" "${LABELS}"
  "--runnergroup" "${RUNNER_GROUP}"
  "--unattended"
  "--replace"
)

if [[ -n "${EPHEMERAL:-}" ]]; then
  log "Enabling ephemeral runner mode"
  CONFIG_ARGS+=("--ephemeral")
fi

if [[ -n "${DISABLE_AUTO_UPDATE:-}" ]]; then
  log "Disabling automatic runner updates"
  CONFIG_ARGS+=("--disableupdate")
fi

if [[ -n "${NO_DEFAULT_LABELS:-}" ]]; then
  log "Removing default labels"
  CONFIG_ARGS+=("--no-default-labels")
fi

log "Configuring runner '${RUNNER_NAME_VALUE}'"
"${CONFIG_SCRIPT}" "${CONFIG_ARGS[@]}"

cleanup() {
  log "Removing runner configuration"
  "${CONFIG_SCRIPT}" remove --unattended --token "${REG_TOKEN}" || true
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

log "Starting runner"
"${RUN_SCRIPT}"
