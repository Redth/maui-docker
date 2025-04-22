#!/usr/bin/bash

GITHUB_ORG=$GITHUB_ORG
GITHUB_REPO=$GITHUB_REPO
GITHUB_TOKEN=$GITHUB_TOKEN

echo "GITHUB_ORG: ${GITHUB_ORG}"
echo "GITHUB_REPO: ${GITHUB_REPO}"

# Check if GITHUB_REPO is specified and use the appropriate API endpoint
if [ -z "$GITHUB_REPO" ] || [ "$GITHUB_REPO" == "" ]; then
    echo "No repository specified, registering runner at organization level"
    REG_TOKEN=$(curl -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token | jq .token --raw-output)
    RUNNER_URL="https://github.com/${GITHUB_ORG}"
else
    echo "Repository specified, registering runner at repository level"
    REG_TOKEN=$(curl -X POST -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/actions/runners/registration-token | jq .token --raw-output)
    RUNNER_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
fi

# Check if the registration token is empty
if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
    echo "ERROR: Failed to obtain registration token. Please check your GitHub token, organization name, and repository name (if provided)."
    echo "Response from GitHub API might indicate an authentication or permission issue."
    exit 1
fi

cd /home/mauiusr/actions-runner


_RANDOM_RUNNER_SUFFIX=${RANDOM_RUNNER_SUFFIX:="true"}
_RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')}
if [[ ${RANDOM_RUNNER_SUFFIX} != "true" ]]; then
  # In some cases this file does not exist
  if [[ -f "/etc/hostname" ]]; then
    # in some cases it can also be empty
    if [[ $(stat --printf="%s" /etc/hostname) -ne 0 ]]; then
      _RUNNER_NAME=${RUNNER_NAME:-${RUNNER_NAME_PREFIX:-github-runner}-$(cat /etc/hostname)}
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX}. /etc/hostname exists and has content. Setting runner name to ${_RUNNER_NAME}"
    else
      echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} ./etc/hostname exists but is empty. Not using /etc/hostname."
    fi
  else
    echo "RANDOM_RUNNER_SUFFIX is ${RANDOM_RUNNER_SUFFIX} but /etc/hostname does not exist. Not using /etc/hostname."
  fi
fi

_RUNNER_WORKDIR=${RUNNER_WORKDIR:-/_work/${_RUNNER_NAME}}
_LABELS=${LABELS:-default}
_RUNNER_GROUP=${RUNNER_GROUP:-Default}

ARGS=()

# shellcheck disable=SC2153
if [ -n "${EPHEMERAL}" ]; then
echo "Ephemeral option is enabled"
ARGS+=("--ephemeral")
fi

if [ -n "${DISABLE_AUTO_UPDATE}" ]; then
echo "Disable auto update option is enabled"
ARGS+=("--disableupdate")
fi

if [ -n "${NO_DEFAULT_LABELS}" ]; then
echo "Disable adding the default self-hosted, platform, and architecture labels"
ARGS+=("--no-default-labels")
fi

echo "Configuring"
./config.sh \
    --url "${RUNNER_URL}" \
    --token "${REG_TOKEN}" \
    --name "${_RUNNER_NAME}" \
    --work "${_RUNNER_WORKDIR}" \
    --labels "${_LABELS}" \
    --runnergroup "${_RUNNER_GROUP}" \
    --unattended \
    --replace \
    "${ARGS[@]}"

[[ ! -d "${_RUNNER_WORKDIR}" ]] && mkdir -p "${_RUNNER_WORKDIR}"


cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${REG_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!