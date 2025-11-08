#!/usr/bin/env bash
set -euo pipefail

# Script to generate SPDX 2.3 format Software Bill of Materials (SBOM)
# Converts the machine-readable JSON software manifest to SPDX format

SOURCE_JSON="${1:-/usr/local/share/installed-software.json}"
OUTPUT_FILE="${2:-/usr/local/share/installed-software.spdx.json}"
TEMP_FILE=$(mktemp)
PACKAGE_IDS_FILE=$(mktemp)

echo "Generating SPDX 2.3 SBOM from ${SOURCE_JSON}..."

# Check if source JSON exists
if [[ ! -f "${SOURCE_JSON}" ]]; then
  echo "ERROR: Source manifest not found: ${SOURCE_JSON}" >&2
  echo "Please run generate-software-manifest.json.sh first" >&2
  exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

# Extract key information from source JSON
IMAGE_TYPE=$(jq -r '.imageType // "maui-development"' "${SOURCE_JSON}")
GENERATED_AT=$(jq -r '.generatedAt // ""' "${SOURCE_JSON}")
OS_VERSION=$(jq -r '.operatingSystem.productVersion // "unknown"' "${SOURCE_JSON}")
OS_BUILD=$(jq -r '.operatingSystem.buildVersion // "unknown"' "${SOURCE_JSON}")
ARCHITECTURE=$(jq -r '.operatingSystem.architecture // "unknown"' "${SOURCE_JSON}")

# Generate document name from build info or defaults
if jq -e '.buildInfo' "${SOURCE_JSON}" >/dev/null 2>&1; then
  DOC_NAME=$(jq -r '.buildInfo.imageName // "maui-development-image"' "${SOURCE_JSON}")
  DOC_VERSION=$(jq -r '.buildInfo.dotnetChannel // "unknown"' "${SOURCE_JSON}")
else
  DOC_NAME="maui-development-image"
  DOC_VERSION="unknown"
fi

# Generate UUID for document namespace (deterministic based on name and timestamp)
if [[ -n "${GENERATED_AT}" ]]; then
  DOC_UUID=$(echo -n "${DOC_NAME}-${GENERATED_AT}" | md5sum | awk '{print $1}' || echo "00000000-0000-0000-0000-000000000000")
  DOC_UUID="${DOC_UUID:0:8}-${DOC_UUID:8:4}-${DOC_UUID:12:4}-${DOC_UUID:16:4}-${DOC_UUID:20:12}"
else
  DOC_UUID="00000000-0000-0000-0000-000000000000"
fi

# Start building SPDX document
cat > "${TEMP_FILE}" << EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": "${DOC_NAME}",
  "documentNamespace": "https://github.com/maui-containers/maui-docker/spdx/${DOC_NAME}-${DOC_UUID}",
  "creationInfo": {
    "created": "${GENERATED_AT}",
    "creators": [
      "Tool: maui-docker-manifest-generator",
      "Organization: MAUI Development Environment"
    ],
    "comment": "SBOM for MAUI development environment containing .NET, Android SDK, Xcode, and development tools"
  },
  "comment": "Software Bill of Materials for ${IMAGE_TYPE} image built for macOS ${OS_VERSION} (${ARCHITECTURE})",
  "packages": [
EOF

# Add operating system as root package
cat >> "${TEMP_FILE}" << EOF
    {
      "SPDXID": "SPDXRef-Package-macOS",
      "name": "macOS",
      "versionInfo": "${OS_VERSION}",
      "supplier": "Organization: Apple Inc.",
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION",
      "comment": "macOS ${OS_VERSION} build ${OS_BUILD}, architecture ${ARCHITECTURE}"
    }
EOF

# Helper function to add a package
add_package() {
  local id="$1"
  local name="$2"
  local version="$3"
  local supplier="${4:-NOASSERTION}"
  local download="${5:-NOASSERTION}"
  local comment="${6:-}"

  # Record package ID for relationships
  echo "SPDXRef-Package-${id}" >> "${PACKAGE_IDS_FILE}"

  cat >> "${TEMP_FILE}" << EOF
,
    {
      "SPDXID": "SPDXRef-Package-${id}",
      "name": "${name}",
      "versionInfo": "${version}",
      "supplier": "${supplier}",
      "downloadLocation": "${download}",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION"$(if [[ -n "${comment}" ]]; then echo ",
      \"comment\": \"${comment}\""; fi)
    }
EOF
}

# Add Xcode
if jq -e '.xcode.defaultVersion' "${SOURCE_JSON}" >/dev/null 2>&1; then
  XCODE_VERSION=$(jq -r '.xcode.defaultVersion // "unknown"' "${SOURCE_JSON}")
  XCODE_BUILD=$(jq -r '.xcode.defaultBuild // ""' "${SOURCE_JSON}")
  if [[ "${XCODE_VERSION}" != "null" && "${XCODE_VERSION}" != "unknown" ]]; then
    COMMENT=""
    [[ -n "${XCODE_BUILD}" && "${XCODE_BUILD}" != "null" ]] && COMMENT="Build ${XCODE_BUILD}"
    add_package "Xcode" "Xcode" "${XCODE_VERSION}" "Organization: Apple Inc." "NOASSERTION" "${COMMENT}"
  fi
fi

# Add .NET SDK
if jq -e '.dotnet.version' "${SOURCE_JSON}" >/dev/null 2>&1; then
  DOTNET_VERSION=$(jq -r '.dotnet.version // "unknown"' "${SOURCE_JSON}")
  if [[ "${DOTNET_VERSION}" != "null" && "${DOTNET_VERSION}" != "unknown" ]]; then
    add_package "dotnet-sdk" "dotnet-sdk" "${DOTNET_VERSION}" "Organization: Microsoft Corporation" "https://dot.net/"
  fi
fi

# Add .NET Workloads
if jq -e '.dotnet.workloads[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.dotnet.workloads[]' "${SOURCE_JSON}" | while read -r workload; do
    [[ -z "${workload}" || "${workload}" == "null" ]] && continue
    add_package "workload-${workload}" "dotnet-workload-${workload}" "installed" "Organization: Microsoft Corporation" "NOASSERTION"
  done
fi

# Add .NET Global Tools
if jq -e '.dotnet.globalTools[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -c '.dotnet.globalTools[]' "${SOURCE_JSON}" | while read -r tool; do
    TOOL_NAME=$(echo "${tool}" | jq -r '.name // ""')
    TOOL_VERSION=$(echo "${tool}" | jq -r '.version // "unknown"')
    [[ -z "${TOOL_NAME}" || "${TOOL_NAME}" == "null" ]] && continue
    TOOL_ID=$(echo "${TOOL_NAME}" | tr '.' '-' | tr '[:upper:]' '[:lower:]')
    add_package "${TOOL_ID}" "${TOOL_NAME}" "${TOOL_VERSION}" "NOASSERTION" "NOASSERTION"
  done
fi

# Add Android SDK packages
if jq -e '.android.platforms[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.android.platforms[]' "${SOURCE_JSON}" | while read -r platform; do
    [[ -z "${platform}" || "${platform}" == "null" ]] && continue
    PLATFORM_ID=$(echo "${platform}" | tr ';' '-' | tr '[:upper:]' '[:lower:]')
    add_package "${PLATFORM_ID}" "${platform}" "installed" "Organization: Google LLC" "https://developer.android.com/studio"
  done
fi

if jq -e '.android.buildTools[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.android.buildTools[]' "${SOURCE_JSON}" | while read -r buildtool; do
    [[ -z "${buildtool}" || "${buildtool}" == "null" ]] && continue
    BUILDTOOL_ID=$(echo "${buildtool}" | tr ';' '-' | tr '[:upper:]' '[:lower:]')
    # Extract version from build-tools;XX.X.X format
    VERSION=$(echo "${buildtool}" | sed 's/build-tools;//')
    add_package "${BUILDTOOL_ID}" "${buildtool}" "${VERSION}" "Organization: Google LLC" "https://developer.android.com/studio"
  done
fi

# Add language runtimes
for lang in node npm python pip ruby java git; do
  if jq -e ".languages.${lang}" "${SOURCE_JSON}" >/dev/null 2>&1; then
    VERSION=$(jq -r ".languages.${lang} // \"unknown\"" "${SOURCE_JSON}")
    if [[ "${VERSION}" != "null" && "${VERSION}" != "unknown" ]]; then
      add_package "${lang}" "${lang}" "${VERSION}" "NOASSERTION" "NOASSERTION"
    fi
  fi
done

# Add package managers
for pm in homebrew gem cocoapods; do
  if jq -e ".packageManagers.${pm}" "${SOURCE_JSON}" >/dev/null 2>&1; then
    VERSION=$(jq -r ".packageManagers.${pm} // \"unknown\"" "${SOURCE_JSON}")
    if [[ "${VERSION}" != "null" && "${VERSION}" != "unknown" ]]; then
      add_package "${pm}" "${pm}" "${VERSION}" "NOASSERTION" "NOASSERTION"
    fi
  fi
done

# Add development tools
if jq -e '.tools' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.tools | to_entries[] | "\(.key)|\(.value)"' "${SOURCE_JSON}" | while IFS='|' read -r tool_name tool_version; do
    [[ -z "${tool_name}" || "${tool_version}" == "null" || "${tool_version}" == "unknown" ]] && continue
    add_package "${tool_name}" "${tool_name}" "${tool_version}" "NOASSERTION" "NOASSERTION"
  done
fi

# Add Homebrew packages (limited to avoid bloat - could make this optional)
# Uncomment the following block if you want ALL homebrew packages in the SBOM
# if jq -e '.homebrewPackages[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
#   jq -c '.homebrewPackages[]' "${SOURCE_JSON}" | while read -r pkg; do
#     PKG_NAME=$(echo "${pkg}" | jq -r '.name // ""')
#     PKG_VERSION=$(echo "${pkg}" | jq -r '.version // "unknown"')
#     [[ -z "${PKG_NAME}" || "${PKG_NAME}" == "null" ]] && continue
#     add_package "brew-${PKG_NAME}" "${PKG_NAME}" "${PKG_VERSION}" "NOASSERTION" "NOASSERTION"
#   done
# fi

# Close packages array
cat >> "${TEMP_FILE}" << 'EOF'
  ],
  "relationships": [
    {
      "spdxElementId": "SPDXRef-DOCUMENT",
      "relationshipType": "DESCRIBES",
      "relatedSpdxElement": "SPDXRef-Package-macOS"
    }
EOF

# Add CONTAINS relationships for all packages to macOS root package
if [[ -s "${PACKAGE_IDS_FILE}" ]]; then
  while read -r pkg_id; do
    [[ -z "${pkg_id}" ]] && continue
    cat >> "${TEMP_FILE}" << EOF
,
    {
      "spdxElementId": "SPDXRef-Package-macOS",
      "relationshipType": "CONTAINS",
      "relatedSpdxElement": "${pkg_id}"
    }
EOF
  done < "${PACKAGE_IDS_FILE}"
fi

# Close relationships array and document
cat >> "${TEMP_FILE}" << 'EOF'
  ]
}
EOF

# Validate JSON with jq
if ! jq empty "${TEMP_FILE}" 2>/dev/null; then
  echo "ERROR: Generated invalid JSON" >&2
  cat "${TEMP_FILE}"
  exit 1
fi

# Pretty-print with jq
jq . "${TEMP_FILE}" > "${TEMP_FILE}.pretty"
mv "${TEMP_FILE}.pretty" "${TEMP_FILE}"

# Move to final location (use sudo only if needed)
OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
if [[ -w "${OUTPUT_DIR}" ]] || [[ ! -d "${OUTPUT_DIR}" && -w "$(dirname "${OUTPUT_DIR}")" ]]; then
  # We have write permission, no sudo needed
  mkdir -p "${OUTPUT_DIR}" 2>/dev/null || true
  mv "${TEMP_FILE}" "${OUTPUT_FILE}"
  chmod 644 "${OUTPUT_FILE}" 2>/dev/null || true
else
  # Need sudo for system directories
  sudo mv "${TEMP_FILE}" "${OUTPUT_FILE}"
  sudo chmod 644 "${OUTPUT_FILE}"
fi

echo "SPDX 2.3 SBOM generated: ${OUTPUT_FILE}"
echo "Document: ${DOC_NAME}"
echo "Namespace: https://github.com/maui-containers/maui-docker/spdx/${DOC_NAME}-${DOC_UUID}"

# Create symlink in home directory
if [[ -d "${HOME}" ]]; then
  ln -sf "${OUTPUT_FILE}" "${HOME}/installed-software.spdx.json" 2>/dev/null || true
  echo "Symlink created: ~/installed-software.spdx.json"
fi

# Cleanup temporary files
rm -f "${PACKAGE_IDS_FILE}"
