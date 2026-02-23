#!/bin/bash

# Script to download OKD installer
# Usage: ./download-okd-installer.sh --version <okd-version> --output-dir <directory>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

load_cache_config

# Function to resolve OKD version to latest matching release
# Usage: resolve_okd_version "4.19"
# Returns: The full version string (e.g., "4.19.0-0.okd-2024-05-10-123456")
resolve_okd_version() {
    local desired_version="$1"

    # Validate input
    if [[ -z "$desired_version" ]]; then
        echo "Error: No version specified" >&2
        return 1
    fi

    # Validate version format (should be X.Y)
    if [[ ! "$desired_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version should be in format X.Y (e.g., 4.19)" >&2
        return 1
    fi

    echo "Resolving OKD version $desired_version..." >&2

    # GitHub API URL for OKD releases
    local api_url="https://api.github.com/repos/okd-project/okd/releases?per_page=100"

    # Fetch releases from GitHub API
    local releases_json
    releases_json=$(curl -s "$api_url")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch releases from GitHub API" >&2
        return 1
    fi

    # Check if we got valid JSON
    if ! echo "$releases_json" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid response from GitHub API" >&2
        return 1
    fi

    # Extract release tags and filter for the desired version
    # OKD releases typically follow the pattern: 4.19.0-0.okd-2024-05-10-123456
    local matching_releases
    matching_releases=$(echo "$releases_json" | jq -r '.[].tag_name' | grep "^$desired_version\." | head -20)

    if [[ -z "$matching_releases" ]]; then
        echo "Error: No releases found for version $desired_version" >&2
        return 1
    fi

    echo "Found matching releases:" >&2
    echo "$matching_releases" | sed 's/^/  /' >&2

    # Sort versions to get the latest one
    # For OKD versions like "4.19.0-okd-scos.15", we need to sort by the numeric suffix
    # Prioritize stable releases (without 'ec') over early candidate releases
    local latest_version
    # First try to get the latest stable release (without 'ec')
    latest_version=$(echo "$matching_releases" | grep -v '\.ec\.' | sort -t. -k4 -n | tail -1)
    # If no stable releases found, fall back to ec releases sorted by field 5
    if [[ -z "$latest_version" ]]; then
        latest_version=$(echo "$matching_releases" | grep '\.ec\.' | sort -t. -k5 -n | tail -1)
    fi

    if [[ -z "$latest_version" ]]; then
        echo "Error: Failed to determine latest version" >&2
        return 1
    fi

    echo "Latest version for $desired_version: $latest_version" >&2
    echo "$latest_version"
}

# Function to get the download URL for the resolved OKD version
# Usage: get_okd_download_url "4.19.0-0.okd-2024-05-10-123456"
get_okd_download_url() {
    local full_version="$1"

    if [[ -z "$full_version" ]]; then
        echo "Error: No version specified" >&2
        return 1
    fi

    echo "Getting download URL for OKD version $full_version..." >&2

    # GitHub API URL for specific release
    local api_url="https://api.github.com/repos/okd-project/okd/releases/tags/$full_version"

    # Fetch release details
    local release_json
    release_json=$(curl -s "$api_url")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to fetch release details from GitHub API" >&2
        return 1
    fi

    # Check if we got valid JSON
    if ! echo "$release_json" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid response from GitHub API" >&2
        return 1
    fi

    # Look for openshift-install tar.gz file
    local download_url
    download_url=$(echo "$release_json" | jq -r '.assets[] | select(.name | test("openshift-install.*linux.*tar\\.gz$")) | .browser_download_url' | head -1)

    if [[ -z "$download_url" ]]; then
        echo "Error: No openshift-install tar.gz found for version $full_version" >&2
        return 1
    fi

    echo "Download URL: $download_url" >&2
    echo "$download_url"
}

# Function to download and extract OKD installer
# Usage: download_okd_installer "4.19"
download_okd_installer() {

    local okd_version="$1"
    if [[ -z "$okd_version" ]] ; then
        echo "Error: Version required." >&2
        return 1
    fi

    local full_version
    full_version=$(resolve_okd_version "$okd_version")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    local output_dir
    output_dir="$BIN_DIR/$full_version"
    mkdir -p "$output_dir"

    local link_dir
    link_dir="$BIN_DIR/$okd_version"
    mkdir -p "$link_dir"

    if [ -f "$output_dir/openshift-install" ]; then
        ln -sf "$output_dir/openshift-install" "$link_dir/openshift-install"
        export OPENSHIFT_INSTALLER="$link_dir/openshift-install"
        echo "OKD installer already exists in $output_dir, skipping download."
        return 0
    fi

    local installer_url
    installer_url=$(get_okd_download_url "$full_version")
    if [[ $? -ne 0 ]] || [[ -z "$installer_url" ]]; then
        echo "Error: Failed to get installer URL for OKD version $okd_version" >&2
        return 1
    fi

    cd "$output_dir" || {
        echo "Error: Failed to change to output directory: $output_dir" >&2
        return 1
    }

    echo "Downloading OKD installer from: $installer_url"
    curl -sS -L -o openshift-install.tar.gz "$installer_url"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to download OKD installer" >&2
        return 1
    fi

    echo "Unpacking OKD installer"
    tar xfz openshift-install.tar.gz
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to unpack OKD installer" >&2
        return 1
    fi

    rm openshift-install.tar.gz
    rm README.md

    ln -sf "$output_dir/openshift-install" "$link_dir/openshift-install"
    export OPENSHIFT_INSTALLER="$link_dir/openshift-install"

    echo "OKD installer successfully downloaded and extracted to: $output_dir"
    return 0
}

# Function to display usage
usage() {
    echo "Usage: $0 --version <okd-version> [--retries <count>]"
    echo ""
    echo "Required Parameters:"
    echo "  --version <okd-version>      OKD version to download (e.g., 4.19)"
    echo ""
    echo "Options:"
    echo "  --retries <count>            Max retry attempts (default: 3)"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --version 4.19"
    echo "  $0 --version 4.19 --retries 5"
    exit 1
}

# Initialize variables
OKD_VERSION=""
MAX_RETRIES=3

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            OKD_VERSION="$2"
            shift 2
            ;;
        --retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$OKD_VERSION" ]]; then
    echo "Error: --version parameter is required"
    usage
fi

# Download the OKD installer with retry
retry_with_backoff "$MAX_RETRIES" "Download OKD installer v${OKD_VERSION}" \
    download_okd_installer "$OKD_VERSION"
exit $?
