#!/bin/bash

# Script to generate install-config.yaml using OpenShift installer
# Usage: ./generate-install-config.sh --ocpVersion <ocp-version>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Function to resolve OCP version to latest stable release
# Usage: resolve_ocp_version "4.16"
# Returns: The version string (e.g., "stable-4.16")
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

    # For OCP, we use the stable channel
    local version_string="stable-$desired_version"

    echo "Using OCP version: $version_string" >&2
    echo "$version_string"
}

# Function to get the download URL for the resolved OCP version
# Usage: get_ocp_download_url "stable-4.16"
get_ocp_download_url() {
    local version_string="$1"

    if [[ -z "$version_string" ]]; then
        echo "Error: No version specified" >&2
        return 1
    fi

    echo "Getting download URL for OCP version $version_string..." >&2

    # OCP download URL pattern
    local download_url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${version_string}/openshift-install-linux.tar.gz"

    echo "Download URL: $download_url" >&2
    echo "$download_url"
}

# Combined function to resolve version and get download URL
# Usage: get_ocp_installer_url "4.16"
get_ocp_installer_url() {
    local desired_version="$1"

    # Resolve to version string
    local version_string
    version_string=$(resolve_ocp_version "$desired_version")

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get download URL
    get_ocp_download_url "$version_string"
}

# Function to display usage
usage() {
    echo "Usage: $0 --ocpVersion <ocp-version>"
    echo ""
    echo "Required Parameters:"
    echo "  --ocpVersion <version>   OCP version to use for installer (e.g., 4.16, 4.17)"
    echo ""
    echo "Optional Parameters:"
    echo "  -h, --help               Show this help message"
    exit 1
}

# Initialize variables
OCP_VERSION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ocpVersion)
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
    echo "Error: --ocpVersion parameter is required"
    usage
fi

# Create work directory
WORK_DIR="$BASE_DIR/ocp-installers/ocp-installer-$OCP_VERSION"

echo "Generating install-config.yaml for OCP version: $OCP_VERSION"
echo "Using work directory: $WORK_DIR"

# Create the work directory (remove if it exists)
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cd "$WORK_DIR"

# Download the OCP installer
echo "Resolving OCP installer download URL..."
INSTALLER_URL=$(get_ocp_installer_url "$OCP_VERSION")

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get installer URL for OCP version $OCP_VERSION"
    exit 1
fi

echo "Downloading OCP installer from: $INSTALLER_URL"
curl -sS -L -o openshift-install.tar.gz "$INSTALLER_URL"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download OCP installer"
    exit 1
fi

# Unpack the installer
echo "Unpacking OCP installer"
tar xfz openshift-install.tar.gz

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to unpack OCP installer"
    exit 1
fi

# Generate install-config.yaml using the OpenShift installer
echo "Generating install-config.yaml using OpenShift installer"
./openshift-install create install-config --dir="$WORK_DIR"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to generate install-config.yaml using installer"
    exit 1
fi

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy install-config.yaml to output directory"
    exit 1
fi

echo ""
echo "Successfully generated install-config.yaml!"
echo "Output file: $WORK_DIR/install-config.yaml"
echo ""
echo "You can now use this file with the OpenShift installer:"
echo "  ./openshift-install create cluster --dir=<cluster-directory>"
