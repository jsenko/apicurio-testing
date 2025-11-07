#!/bin/bash

# Script to download OCP installer
# Usage: ./download-ocp-installer.sh --version <ocp-version>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

load_cache_config

# Resolves OCP version to the latest stable or specific version
# Usage: resolve_ocp_version "4.16"
# Returns: The full version string to download (e.g., "stable-4.16")
resolve_ocp_version() {
    local desired_version="$1"

    # Validate input
    if [[ -z "$desired_version" ]]; then
        echo "Error: No version specified" >&2
        return 1
    fi

    # Validate version format (should be X.Y)
    if [[ ! "$desired_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version should be in format X.Y (e.g., 4.16)" >&2
        return 1
    fi

    echo "Resolving OCP version $desired_version..." >&2

    # For OCP, we use the stable release channel
    # We can either use "stable-X.Y" or fetch specific versions
    local version_string="stable-${desired_version}"

    echo "Using stable release channel: $version_string" >&2
    echo "$version_string"
}

# Gets the download URL for the OCP installer
# Usage: get_ocp_download_url "stable-4.16"
# Returns: The download URL for the openshift-install binary
get_ocp_download_url() {
    local version_string="$1"

    if [[ -z "$version_string" ]]; then
        echo "Error: No version specified" >&2
        return 1
    fi

    echo "Getting download URL for OCP version $version_string..." >&2

    # OCP installer is hosted on Red Hat's mirror site
    local base_url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp"
    local download_url="${base_url}/${version_string}/openshift-install-linux.tar.gz"

    echo "Download URL: $download_url" >&2
    echo "$download_url"
}

# Downloads and extracts the OCP installer
# Usage: download_ocp_installer "4.16"
# Returns: 0 on success, 1 on failure
download_ocp_installer() {
    local ocp_version="$1"

    if [[ -z "$ocp_version" ]]; then
        echo "Error: Version required." >&2
        return 1
    fi

    local version_string
    version_string=$(resolve_ocp_version "$ocp_version")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    local output_dir
    output_dir="$BIN_DIR/$version_string"
    mkdir -p "$output_dir"

    local link_dir
    link_dir="$BIN_DIR/$ocp_version"
    mkdir -p "$link_dir"

    if [ -f "$output_dir/openshift-install" ]; then
        ln -sf "$output_dir/openshift-install" "$link_dir/openshift-install"
        export OPENSHIFT_INSTALLER="$link_dir/openshift-install"
        echo "OCP installer already exists in $output_dir, skipping download."
        return 0
    fi

    local installer_url
    installer_url=$(get_ocp_download_url "$version_string")
    if [[ $? -ne 0 ]] || [[ -z "$installer_url" ]]; then
        echo "Error: Failed to get installer URL for OCP version $ocp_version" >&2
        return 1
    fi

    cd "$output_dir" || {
        echo "Error: Failed to change to output directory: $output_dir" >&2
        return 1
    }

    echo "Downloading OCP installer from: $installer_url"
    curl -sS -L -o openshift-install.tar.gz "$installer_url"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to download OCP installer" >&2
        echo "Note: Ensure you have network access to mirror.openshift.com" >&2
        return 1
    fi

    echo "Unpacking OCP installer"
    tar xfz openshift-install.tar.gz
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to unpack OCP installer" >&2
        return 1
    fi

    rm openshift-install.tar.gz
    rm -f README.md

    ln -sf "$output_dir/openshift-install" "$link_dir/openshift-install"
    export OPENSHIFT_INSTALLER="$link_dir/openshift-install"

    echo "OCP installer successfully downloaded and extracted to: $output_dir"

    # Display version information
    "$link_dir/openshift-install" version

    return 0
}

# Displays usage information
usage() {
    echo "Usage: $0 --version <ocp-version>"
    echo ""
    echo "Required Parameters:"
    echo "  --version <ocp-version>      OCP version to download (e.g., 4.16)"
    echo ""
    echo "Options:"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --version 4.16"
    echo ""
    echo "Supported Versions:"
    echo "  4.16 - Stable release (recommended)"
    echo "  4.17 - Future stable release"
    exit 1
}

# Initialize variables
OCP_VERSION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            OCP_VERSION="$2"
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
if [[ -z "$OCP_VERSION" ]]; then
    echo "Error: --version parameter is required"
    usage
fi

# Download the OCP installer
download_ocp_installer "$OCP_VERSION"
exit $?
