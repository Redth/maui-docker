#!/usr/bin/bash

# Use environment variables with defaults to ensure we don't have empty values
GITEA_INSTANCE_URL=${GITEA_INSTANCE_URL:-""}
GITEA_RUNNER_TOKEN=${GITEA_RUNNER_TOKEN:-""}
GITEA_RUNNER_NAME=${GITEA_RUNNER_NAME:-""}

INIT_PWSH_SCRIPT=${INIT_PWSH_SCRIPT:-""}
INIT_BASH_SCRIPT=${INIT_BASH_SCRIPT:-""}

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

# Log environment variables for debugging
echo "GITEA_INSTANCE_URL: ${GITEA_INSTANCE_URL}"

# Check if required environment variables are set
if [ -z "$GITEA_INSTANCE_URL" ] || [ "$GITEA_INSTANCE_URL" == "" ]; then
    echo "ERROR: GITEA_INSTANCE_URL environment variable is not set"
    exit 1
fi

if [ -z "$GITEA_RUNNER_TOKEN" ] || [ "$GITEA_RUNNER_TOKEN" == "" ]; then
    echo "ERROR: GITEA_RUNNER_TOKEN environment variable is not set"
    exit 1
fi

cd /home/mauiusr/gitea-runner

# Generate runner name if not provided
_RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:="true"}
if [ -z "$GITEA_RUNNER_NAME" ]; then
  _RUNNER_NAME_PREFIX=${GITEA_RUNNER_NAME_PREFIX:-gitea-runner}
  if [[ ${RANDOM_RUNNER_SUFFIX} == "true" ]]; then
    _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
  else
    # In some cases this file does not exist
    if [[ -f "/etc/hostname" ]]; then
      # in some cases it can also be empty
      if [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
        _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(cat /etc/hostname)
        echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${_RUNNER_NAME}"
      else
        echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists but is empty. Using random suffix."
        _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
      fi
    else
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname does not exist. Using random suffix."
      _RUNNER_NAME=${_RUNNER_NAME_PREFIX}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')
    fi
  fi
else
  _RUNNER_NAME=$GITEA_RUNNER_NAME
fi

_LABELS=${GITEA_RUNNER_LABELS:-maui,linux,amd64}

echo "Registering Gitea runner: ${_RUNNER_NAME}"
echo "Labels: ${_LABELS}"

# Register the runner if not already registered
if [ ! -f ".runner" ]; then
  echo "Registering runner with Gitea..."
  ./act_runner register \
    --instance "${GITEA_INSTANCE_URL}" \
    --token "${GITEA_RUNNER_TOKEN}" \
    --name "${_RUNNER_NAME}" \
    --labels "${_LABELS}" \
    --no-interactive

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to register runner with Gitea"
    exit 1
  fi

  echo "Runner registered successfully"
else
  echo "Runner already registered (found .runner file)"
fi

cleanup() {
    echo "Shutting down Gitea runner..."
    # Gitea runner doesn't have a built-in removal command like GitHub
    # The runner will just stop and can be removed from Gitea UI if needed
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "Starting Gitea runner daemon..."
./act_runner daemon & wait $!
