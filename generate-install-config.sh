#!/bin/bash

# Script to generate install-config.yaml using OpenShift installer
# Usage: ./generate-install-config.sh --okdVersion <okd-version>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


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
    # We'll use version sort which handles the semantic versioning correctly
    local latest_version
    latest_version=$(echo "$matching_releases" | head -1)
    
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

# Combined function to resolve version and get download URL
# Usage: get_okd_installer_url "4.19"
get_okd_installer_url() {
    local desired_version="$1"
    
    # Resolve to full version
    local full_version
    full_version=$(resolve_okd_version "$desired_version")
    
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Get download URL
    get_okd_download_url "$full_version"
}

# Function to display usage
usage() {
    echo "Usage: $0 --okdVersion <okd-version>"
    echo ""
    echo "Required Parameters:"
    echo "  --okdVersion <version>   OKD version to use for installer (e.g., 4.19, 4.14)"
    echo ""
    echo "Optional Parameters:"
    echo "  -h, --help               Show this help message"
    exit 1
}

# Initialize variables
OKD_VERSION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --okdVersion)
            OKD_VERSION="$2"
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
    echo "Error: --okdVersion parameter is required"
    usage
fi

# Create work directory
WORK_DIR="$BASE_DIR/okd-installers/okd-installer-$OKD_VERSION"

echo "Generating install-config.yaml for OKD version: $OKD_VERSION"
echo "Using work directory: $WORK_DIR"

# Create the work directory (remove if it exists)
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cd "$WORK_DIR"

# Download the OKD installer
echo "Resolving OKD installer download URL..."
INSTALLER_URL=$(get_okd_installer_url "$OKD_VERSION")

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get installer URL for OKD version $OKD_VERSION"
    exit 1
fi

echo "Downloading OKD installer from: $INSTALLER_URL"
curl -sS -L -o openshift-install.tar.gz "$INSTALLER_URL"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download OKD installer"
    exit 1
fi

# Unpack the installer
echo "Unpacking OKD installer"
tar xfz openshift-install.tar.gz

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to unpack OKD installer"
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
