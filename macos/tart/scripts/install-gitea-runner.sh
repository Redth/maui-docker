#!/usr/bin/env bash
set -euo pipefail

echo 'Installing Gitea Actions runner...'
mkdir -p /Users/admin/gitea-runner
cd /Users/admin/gitea-runner

# Detect architecture
ARCH=$(uname -m)
if [ "${ARCH}" = "arm64" ]; then
  DOWNLOAD_ARCH="arm64"
else
  DOWNLOAD_ARCH="amd64"
fi
echo "Detected architecture: ${ARCH} (downloading ${DOWNLOAD_ARCH})"

# Get latest release and extract the correct download URL from assets
curl -fsSL https://gitea.com/api/v1/repos/gitea/act_runner/releases -o /tmp/releases.json
LATEST_VERSION=$(jq -r '.[0].tag_name' /tmp/releases.json)
# Remove 'v' prefix from version for filename matching
VERSION_NO_V=$(echo "${LATEST_VERSION}" | sed 's/^v//')
# Find the matching asset by name
DOWNLOAD_URL=$(jq -r ".[0].assets[] | select(.name == \"act_runner-${VERSION_NO_V}-darwin-${DOWNLOAD_ARCH}\") | .browser_download_url" /tmp/releases.json)
rm -f /tmp/releases.json
echo "Latest act_runner version: ${LATEST_VERSION}"
echo "Downloading from: ${DOWNLOAD_URL}"
curl -fsSL "${DOWNLOAD_URL}" -o act_runner
chmod +x act_runner

# Move helper script into place
mv /tmp/gitea-runner.sh /Users/admin/gitea-runner/gitea-runner.sh
chmod +x /Users/admin/gitea-runner/gitea-runner.sh
chown -R admin:staff /Users/admin/gitea-runner

echo 'Gitea Actions runner installed'
echo 'Runner binary: /Users/admin/gitea-runner/act_runner'
echo 'Runner helper script: /Users/admin/gitea-runner/gitea-runner.sh'
