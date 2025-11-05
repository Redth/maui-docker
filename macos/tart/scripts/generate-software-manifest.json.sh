#!/usr/bin/env bash
set -euo pipefail

# Script to generate machine-readable JSON software manifest
# Companion to generate-software-manifest.sh

OUTPUT_FILE="${1:-/usr/local/share/installed-software.json}"
TEMP_FILE=$(mktemp)

echo "Generating JSON software manifest..."

# Start JSON structure
cat > "${TEMP_FILE}" << 'EOF'
{
  "manifestVersion": "1.0",
  "imageType": "maui-development",
  "generatedAt": "
EOF

echo -n "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "${TEMP_FILE}"

cat >> "${TEMP_FILE}" << 'EOF'
",
  "operatingSystem": {
EOF

# OS Information
echo "    \"productVersion\": \"$(sw_vers -productVersion)\"," >> "${TEMP_FILE}"
echo "    \"buildVersion\": \"$(sw_vers -buildVersion)\"," >> "${TEMP_FILE}"
echo "    \"kernelVersion\": \"$(uname -r)\"," >> "${TEMP_FILE}"
echo "    \"architecture\": \"$(uname -m)\"" >> "${TEMP_FILE}"

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "xcode": {
EOF

if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "unknown")
  XCODE_BUILD=$(xcodebuild -version 2>/dev/null | grep "Build version" | awk '{print $3}' || echo "unknown")

  echo "    \"defaultVersion\": \"${XCODE_VERSION}\"," >> "${TEMP_FILE}"
  echo "    \"defaultBuild\": \"${XCODE_BUILD}\"," >> "${TEMP_FILE}"

  # All installed versions
  if command -v xcodes >/dev/null 2>&1; then
    echo "    \"installedVersions\": [" >> "${TEMP_FILE}"
    xcodes installed 2>/dev/null | tail -n +2 | awk '{print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
    echo "    ]," >> "${TEMP_FILE}"
  else
    echo "    \"installedVersions\": []," >> "${TEMP_FILE}"
  fi

  # SDKs
  echo "    \"sdks\": [" >> "${TEMP_FILE}"
  xcodebuild -showsdks 2>/dev/null | grep -E "iOS|macOS|tvOS|watchOS|visionOS" | awk '{print $NF}' | sed 's/^/      "/' | sed 's/$/"/' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]" >> "${TEMP_FILE}"
else
  echo "    \"defaultVersion\": null," >> "${TEMP_FILE}"
  echo "    \"defaultBuild\": null," >> "${TEMP_FILE}"
  echo "    \"installedVersions\": []," >> "${TEMP_FILE}"
  echo "    \"sdks\": []" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "dotnet": {
EOF

if command -v dotnet >/dev/null 2>&1; then
  DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
  echo "    \"version\": \"${DOTNET_VERSION}\"," >> "${TEMP_FILE}"

  # SDKs
  echo "    \"sdks\": [" >> "${TEMP_FILE}"
  dotnet --list-sdks 2>/dev/null | awk '{print "      {\"version\": \"" $1 "\", \"path\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]," >> "${TEMP_FILE}"

  # Runtimes
  echo "    \"runtimes\": [" >> "${TEMP_FILE}"
  dotnet --list-runtimes 2>/dev/null | awk '{print "      {\"name\": \"" $1 "\", \"version\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]," >> "${TEMP_FILE}"

  # Workloads
  echo "    \"workloads\": [" >> "${TEMP_FILE}"
  dotnet workload list 2>/dev/null | tail -n +3 | head -n -2 | awk '{print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]," >> "${TEMP_FILE}"

  # Global tools
  echo "    \"globalTools\": [" >> "${TEMP_FILE}"
  dotnet tool list -g 2>/dev/null | tail -n +3 | awk '{print "      {\"name\": \"" $1 "\", \"version\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
  echo "    ]" >> "${TEMP_FILE}"
else
  echo "    \"version\": null," >> "${TEMP_FILE}"
  echo "    \"sdks\": []," >> "${TEMP_FILE}"
  echo "    \"runtimes\": []," >> "${TEMP_FILE}"
  echo "    \"workloads\": []," >> "${TEMP_FILE}"
  echo "    \"globalTools\": []" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "android": {
EOF

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [[ -d "${ANDROID_HOME}" ]]; then
  echo "    \"sdkRoot\": \"${ANDROID_HOME}\"," >> "${TEMP_FILE}"

  if [[ -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    # Platforms
    echo "    \"platforms\": [" >> "${TEMP_FILE}"
    "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep "platforms;" | awk '{print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
    echo "    ]," >> "${TEMP_FILE}"

    # Build tools
    echo "    \"buildTools\": [" >> "${TEMP_FILE}"
    "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep "build-tools;" | awk '{print "      \"" $1 "\""}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '      ' >> "${TEMP_FILE}"
    echo "    ]" >> "${TEMP_FILE}"
  else
    echo "    \"platforms\": []," >> "${TEMP_FILE}"
    echo "    \"buildTools\": []" >> "${TEMP_FILE}"
  fi
else
  echo "    \"sdkRoot\": null," >> "${TEMP_FILE}"
  echo "    \"platforms\": []," >> "${TEMP_FILE}"
  echo "    \"buildTools\": []" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "languages": {
EOF

# Language versions
echo -n "    \"node\": " >> "${TEMP_FILE}"
if command -v node >/dev/null 2>&1; then
  echo "\"$(node --version 2>/dev/null | sed 's/^v//')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"npm\": " >> "${TEMP_FILE}"
if command -v npm >/dev/null 2>&1; then
  echo "\"$(npm --version 2>/dev/null)\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"python\": " >> "${TEMP_FILE}"
if command -v python3 >/dev/null 2>&1; then
  echo "\"$(python3 --version 2>/dev/null | awk '{print $2}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"pip\": " >> "${TEMP_FILE}"
if command -v pip3 >/dev/null 2>&1; then
  echo "\"$(pip3 --version 2>/dev/null | awk '{print $2}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"ruby\": " >> "${TEMP_FILE}"
if command -v ruby >/dev/null 2>&1; then
  echo "\"$(ruby --version 2>/dev/null | awk '{print $2}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"java\": " >> "${TEMP_FILE}"
if command -v java >/dev/null 2>&1; then
  JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
  echo "\"${JAVA_VERSION}\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"git\": " >> "${TEMP_FILE}"
if command -v git >/dev/null 2>&1; then
  echo "\"$(git --version 2>/dev/null | awk '{print $3}')\"" >> "${TEMP_FILE}"
else
  echo "null" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "packageManagers": {
EOF

echo -n "    \"homebrew\": " >> "${TEMP_FILE}"
if command -v brew >/dev/null 2>&1; then
  echo "\"$(brew --version 2>/dev/null | head -n 1 | awk '{print $2}')\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"gem\": " >> "${TEMP_FILE}"
if command -v gem >/dev/null 2>&1; then
  echo "\"$(gem --version 2>/dev/null)\"," >> "${TEMP_FILE}"
else
  echo "null," >> "${TEMP_FILE}"
fi

echo -n "    \"cocoapods\": " >> "${TEMP_FILE}"
if command -v pod >/dev/null 2>&1; then
  echo "\"$(pod --version 2>/dev/null)\"" >> "${TEMP_FILE}"
else
  echo "null" >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "tools": {
EOF

# Development tools
TOOLS=(curl wget jq gh cmake fastlane xcbeautify)
TOOL_COUNT=${#TOOLS[@]}
CURRENT=0

for tool in "${TOOLS[@]}"; do
  CURRENT=$((CURRENT + 1))
  echo -n "    \"${tool}\": " >> "${TEMP_FILE}"

  if command -v "${tool}" >/dev/null 2>&1; then
    VERSION=$("${tool}" --version 2>/dev/null | head -n 1 | awk '{print $NF}' || echo "installed")
    echo -n "\"${VERSION}\"" >> "${TEMP_FILE}"
  else
    echo -n "null" >> "${TEMP_FILE}"
  fi

  if [[ ${CURRENT} -lt ${TOOL_COUNT} ]]; then
    echo "," >> "${TEMP_FILE}"
  else
    echo "" >> "${TEMP_FILE}"
  fi
done

cat >> "${TEMP_FILE}" << 'EOF'
  },
  "homebrewPackages": [
EOF

if command -v brew >/dev/null 2>&1; then
  brew list --versions 2>/dev/null | awk '{print "    {\"name\": \"" $1 "\", \"version\": \"" $2 "\"}"}' | paste -sd ',' - >> "${TEMP_FILE}" || echo '    ' >> "${TEMP_FILE}"
fi

cat >> "${TEMP_FILE}" << 'EOF'
  ],
  "environmentVariables": {
    "DOTNET_ROOT": "/Users/admin/.dotnet",
    "ANDROID_HOME": "~/Library/Android/sdk",
    "ANDROID_SDK_ROOT": "~/Library/Android/sdk"
  },
  "ciRunners": {
    "githubActions": {
      "scriptPath": "/Users/admin/actions-runner/maui-runner.sh",
      "autoStart": true,
      "configurationMethod": ".env file via --dir config"
    },
    "giteaActions": {
      "binaryPath": "/Users/admin/gitea-runner/act_runner",
      "scriptPath": "/Users/admin/gitea-runner/gitea-runner.sh",
      "autoStart": true,
      "configurationMethod": ".env file via --dir config"
    }
  }
EOF

# Include build info if available
if [[ -f /usr/local/share/build-info.json ]]; then
  echo "  ," >> "${TEMP_FILE}"
  echo "  \"buildInfo\": " >> "${TEMP_FILE}"
  cat /usr/local/share/build-info.json >> "${TEMP_FILE}"
fi

# Close JSON
echo "" >> "${TEMP_FILE}"
echo "}" >> "${TEMP_FILE}"

# Validate JSON before moving
if command -v jq >/dev/null 2>&1; then
  if ! jq empty "${TEMP_FILE}" 2>/dev/null; then
    echo "ERROR: Generated invalid JSON" >&2
    cat "${TEMP_FILE}"
    exit 1
  fi
  # Pretty-print with jq
  jq . "${TEMP_FILE}" > "${TEMP_FILE}.pretty"
  mv "${TEMP_FILE}.pretty" "${TEMP_FILE}"
fi

# Move to final location
sudo mv "${TEMP_FILE}" "${OUTPUT_FILE}"
sudo chmod 644 "${OUTPUT_FILE}"

echo "JSON software manifest generated: ${OUTPUT_FILE}"
