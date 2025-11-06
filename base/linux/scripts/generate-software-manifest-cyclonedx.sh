#!/usr/bin/env bash
set -euo pipefail

# Script to generate CycloneDX 1.6 format Software Bill of Materials (SBOM)
# Converts the machine-readable JSON software manifest to CycloneDX format
# Docker/Linux version

SOURCE_JSON="${1:-/usr/local/share/installed-software.json}"
OUTPUT_FILE="${2:-/usr/local/share/installed-software.cdx.json}"
TEMP_FILE=$(mktemp)

echo "Generating CycloneDX 1.6 SBOM from ${SOURCE_JSON}..."

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
IMAGE_TYPE=$(jq -r '.imageType // "maui-docker-development"' "${SOURCE_JSON}")
GENERATED_AT=$(jq -r '.generatedAt // ""' "${SOURCE_JSON}")
OS_DIST=$(jq -r '.operatingSystem.distribution // "linux"' "${SOURCE_JSON}")
OS_VERSION=$(jq -r '.operatingSystem.version // "unknown"' "${SOURCE_JSON}")
OS_CODENAME=$(jq -r '.operatingSystem.versionCodename // ""' "${SOURCE_JSON}")
ARCHITECTURE=$(jq -r '.operatingSystem.architecture // "unknown"' "${SOURCE_JSON}")

# Generate BOM metadata from build info or defaults
if jq -e '.buildInfo' "${SOURCE_JSON}" >/dev/null 2>&1; then
  BOM_NAME=$(jq -r '.buildInfo.imageName // "maui-development-image"' "${SOURCE_JSON}")
  BOM_VERSION=$(jq -r '.buildInfo.dotnetChannel // "1.0"' "${SOURCE_JSON}")
else
  BOM_NAME="maui-development-image"
  BOM_VERSION="1.0"
fi

# Generate UUID for serial number (deterministic based on name and timestamp)
if [[ -n "${GENERATED_AT}" ]]; then
  BOM_UUID=$(echo -n "${BOM_NAME}-${GENERATED_AT}" | md5sum | awk '{print $1}' || echo "00000000-0000-0000-0000-000000000000")
  BOM_UUID="${BOM_UUID:0:8}-${BOM_UUID:8:4}-${BOM_UUID:12:4}-${BOM_UUID:16:4}-${BOM_UUID:20:12}"
else
  BOM_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' 2>/dev/null || echo "00000000-0000-0000-0000-000000000000")
fi

# Start building CycloneDX document
cat > "${TEMP_FILE}" << EOF
{
  "\$schema": "http://cyclonedx.org/schema/bom-1.6.schema.json",
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "serialNumber": "urn:uuid:${BOM_UUID}",
  "version": 1,
  "metadata": {
    "timestamp": "${GENERATED_AT}",
    "tools": [
      {
        "vendor": "MAUI Development Environment",
        "name": "maui-docker-manifest-generator",
        "version": "1.0"
      }
    ],
    "component": {
      "type": "container",
      "bom-ref": "pkg:oci/${BOM_NAME}@${BOM_VERSION}",
      "name": "${BOM_NAME}",
      "version": "${BOM_VERSION}",
      "description": "MAUI Docker development environment with .NET, Android SDK, and development tools"
    }
  },
  "components": [
EOF

# Helper function to add a component
add_component() {
  local bom_ref="$1"
  local type="$2"
  local name="$3"
  local version="$4"
  local supplier="${5:-}"
  local description="${6:-}"
  local is_first="${7:-false}"

  # Add comma if not first component
  [[ "${is_first}" == "false" ]] && echo "," >> "${TEMP_FILE}"

  cat >> "${TEMP_FILE}" << EOF
    {
      "type": "${type}",
      "bom-ref": "${bom_ref}",
      "name": "${name}",
      "version": "${version}"$(if [[ -n "${supplier}" ]]; then echo ",
      \"supplier\": {
        \"name\": \"${supplier}\"
      }"; fi)$(if [[ -n "${description}" ]]; then echo ",
      \"description\": \"${description}\""; fi)
    }
EOF
}

# Track if we've added the first component
FIRST_COMPONENT=true

# Add Linux OS as operating-system component
OS_DESC="${OS_DIST} ${OS_VERSION}"
[[ -n "${OS_CODENAME}" && "${OS_CODENAME}" != "unknown" ]] && OS_DESC="${OS_DESC} (${OS_CODENAME}), architecture ${ARCHITECTURE}"
add_component "pkg:generic/${OS_DIST}@${OS_VERSION}" "operating-system" "${OS_DIST}" "${OS_VERSION}" "" "${OS_DESC}" "${FIRST_COMPONENT}"
FIRST_COMPONENT=false

# Add Java/JDK
if jq -e '.java.version' "${SOURCE_JSON}" >/dev/null 2>&1; then
  JAVA_VERSION=$(jq -r '.java.version // "unknown"' "${SOURCE_JSON}")
  if [[ "${JAVA_VERSION}" != "null" && "${JAVA_VERSION}" != "unknown" ]]; then
    add_component "pkg:generic/msopenjdk@${JAVA_VERSION}" "application" "Microsoft OpenJDK" "${JAVA_VERSION}" "Microsoft Corporation" "Microsoft Build of OpenJDK" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  fi
fi

# Add .NET SDK
if jq -e '.dotnet.version' "${SOURCE_JSON}" >/dev/null 2>&1; then
  DOTNET_VERSION=$(jq -r '.dotnet.version // "unknown"' "${SOURCE_JSON}")
  if [[ "${DOTNET_VERSION}" != "null" && "${DOTNET_VERSION}" != "unknown" ]]; then
    add_component "pkg:nuget/Microsoft.NET.Sdk@${DOTNET_VERSION}" "framework" "dotnet-sdk" "${DOTNET_VERSION}" "Microsoft Corporation" ".NET SDK" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  fi
fi

# Add .NET Workloads
if jq -e '.dotnet.workloads[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.dotnet.workloads[]' "${SOURCE_JSON}" | while read -r workload; do
    [[ -z "${workload}" || "${workload}" == "null" ]] && continue
    WORKLOAD_NAME="dotnet-workload-${workload}"
    add_component "pkg:nuget/${WORKLOAD_NAME}@installed" "framework" "${WORKLOAD_NAME}" "installed" "Microsoft Corporation" ".NET ${workload} workload" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  done
fi

# Add .NET Global Tools
if jq -e '.dotnet.globalTools[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -c '.dotnet.globalTools[]' "${SOURCE_JSON}" | while read -r tool; do
    TOOL_NAME=$(echo "${tool}" | jq -r '.name // ""')
    TOOL_VERSION=$(echo "${tool}" | jq -r '.version // "unknown"')
    [[ -z "${TOOL_NAME}" || "${TOOL_NAME}" == "null" ]] && continue
    add_component "pkg:nuget/${TOOL_NAME}@${TOOL_VERSION}" "application" "${TOOL_NAME}" "${TOOL_VERSION}" "" ".NET global tool" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  done
fi

# Add Android SDK platforms
if jq -e '.android.platforms[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.android.platforms[]' "${SOURCE_JSON}" | while read -r platform; do
    [[ -z "${platform}" || "${platform}" == "null" ]] && continue
    # Extract API level from platforms;android-XX
    API_LEVEL=$(echo "${platform}" | sed 's/platforms;android-//')
    add_component "pkg:generic/android-platform@${API_LEVEL}" "framework" "${platform}" "${API_LEVEL}" "Google LLC" "Android SDK Platform" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  done
fi

# Add Android SDK build tools
if jq -e '.android.buildTools[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.android.buildTools[]' "${SOURCE_JSON}" | while read -r buildtool; do
    [[ -z "${buildtool}" || "${buildtool}" == "null" ]] && continue
    # Extract version from build-tools;XX.X.X format
    VERSION=$(echo "${buildtool}" | sed 's/build-tools;//')
    add_component "pkg:generic/android-build-tools@${VERSION}" "library" "${buildtool}" "${VERSION}" "Google LLC" "Android SDK Build Tools" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  done
fi

# Add language runtimes
for lang in node npm python pip ruby java git; do
  if jq -e ".languages.${lang}" "${SOURCE_JSON}" >/dev/null 2>&1; then
    VERSION=$(jq -r ".languages.${lang} // \"unknown\"" "${SOURCE_JSON}")
    if [[ "${VERSION}" != "null" && "${VERSION}" != "unknown" ]]; then
      # Determine component type
      case "${lang}" in
        node|python|ruby|java) COMP_TYPE="application" ;;
        npm|pip|git) COMP_TYPE="application" ;;
        *) COMP_TYPE="library" ;;
      esac
      add_component "pkg:generic/${lang}@${VERSION}" "${COMP_TYPE}" "${lang}" "${VERSION}" "" "" "${FIRST_COMPONENT}"
      FIRST_COMPONENT=false
    fi
  fi
done

# Add package managers
for pm in homebrew gem cocoapods; do
  if jq -e ".packageManagers.${pm}" "${SOURCE_JSON}" >/dev/null 2>&1; then
    VERSION=$(jq -r ".packageManagers.${pm} // \"unknown\"" "${SOURCE_JSON}")
    if [[ "${VERSION}" != "null" && "${VERSION}" != "unknown" ]]; then
      PM_DESC=""
      case "${pm}" in
        homebrew) PM_DESC="The Missing Package Manager for macOS" ;;
        gem) PM_DESC="RubyGems package manager" ;;
        cocoapods) PM_DESC="Dependency manager for Swift and Objective-C" ;;
      esac
      add_component "pkg:generic/${pm}@${VERSION}" "application" "${pm}" "${VERSION}" "" "${PM_DESC}" "${FIRST_COMPONENT}"
      FIRST_COMPONENT=false
    fi
  fi
done

# Add development tools
if jq -e '.tools' "${SOURCE_JSON}" >/dev/null 2>&1; then
  jq -r '.tools | to_entries[] | "\(.key)|\(.value)"' "${SOURCE_JSON}" | while IFS='|' read -r tool_name tool_version; do
    [[ -z "${tool_name}" || "${tool_version}" == "null" || "${tool_version}" == "unknown" ]] && continue
    add_component "pkg:generic/${tool_name}@${tool_version}" "application" "${tool_name}" "${tool_version}" "" "" "${FIRST_COMPONENT}"
    FIRST_COMPONENT=false
  done
fi

# Add selected Homebrew packages (optional - uncomment to include all)
# if jq -e '.homebrewPackages[]' "${SOURCE_JSON}" >/dev/null 2>&1; then
#   jq -c '.homebrewPackages[]' "${SOURCE_JSON}" | while read -r pkg; do
#     PKG_NAME=$(echo "${pkg}" | jq -r '.name // ""')
#     PKG_VERSION=$(echo "${pkg}" | jq -r '.version // "unknown"')
#     [[ -z "${PKG_NAME}" || "${PKG_NAME}" == "null" ]] && continue
#     add_component "pkg:brew/${PKG_NAME}@${PKG_VERSION}" "library" "${PKG_NAME}" "${PKG_VERSION}" "" "" "${FIRST_COMPONENT}"
#     FIRST_COMPONENT=false
#   done
# fi

# Close components array and add dependencies
echo "" >> "${TEMP_FILE}"
echo "  ]," >> "${TEMP_FILE}"
echo "  \"dependencies\": [" >> "${TEMP_FILE}"
echo "    {" >> "${TEMP_FILE}"
echo "      \"ref\": \"pkg:oci/${BOM_NAME}@${BOM_VERSION}\"," >> "${TEMP_FILE}"
echo "      \"dependsOn\": [" >> "${TEMP_FILE}"
echo "        \"pkg:generic/${OS_DIST}@${OS_VERSION}\"" >> "${TEMP_FILE}"
echo "      ]" >> "${TEMP_FILE}"
echo "    }" >> "${TEMP_FILE}"
echo "  ]" >> "${TEMP_FILE}"
echo "}" >> "${TEMP_FILE}"

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

echo "CycloneDX 1.6 SBOM generated: ${OUTPUT_FILE}"
echo "BOM: ${BOM_NAME} version ${BOM_VERSION}"
echo "Serial Number: urn:uuid:${BOM_UUID}"

# Create symlink in home directory
if [[ -d "${HOME}" ]]; then
  ln -sf "${OUTPUT_FILE}" "${HOME}/installed-software.cdx.json" 2>/dev/null || true
  echo "Symlink created: ~/installed-software.cdx.json"
fi
