#!/bin/bash

# Script to install OKD cluster
# Usage: ./install-cluster.sh --clusterName <cluster-name>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to validate required environment variables
validate_env_vars() {
    local missing_vars=()
    
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
        missing_vars+=("AWS_ACCESS_KEY_ID")
    fi
    
    if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        missing_vars+=("AWS_SECRET_ACCESS_KEY")
    fi
    
    if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
        missing_vars+=("AWS_DEFAULT_REGION")
    fi
    
    if [[ -z "${OPENSHIFT_PULL_SECRET:-}" ]]; then
        missing_vars+=("OPENSHIFT_PULL_SECRET")
    fi
    
    if [[ -z "${SSH_PUBLIC_KEY:-}" ]]; then
        missing_vars+=("SSH_PUBLIC_KEY")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "Error: The following required environment variables are not set:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please set these environment variables before running the script."
        exit 1
    fi
}


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
    local api_url="https://api.github.com/repos/okd-project/okd/releases"
    
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
    echo "Usage: $0 --clusterName <cluster-name> [--okdVersion <okd-version>]"
    echo ""
    echo "Required Parameters:"
    echo "  --clusterName <cluster-name>    Name of the cluster to install"
    echo "                           Must contain only letters and numbers"
    echo ""
    echo "Optional Parameters:"
    echo "  --okdVersion <version>   OKD version to install (default: 4.19)"
    echo "  -h, --help               Show this help message"
    exit 1
}

# Initialize variables
CLUSTER_NAME=""
OKD_VERSION="4.19"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clusterName)
            CLUSTER_NAME="$2"
            shift 2
            ;;
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
if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: --clusterName parameter is required"
    usage
fi

# Validate cluster name format (only letters and numbers allowed)
if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Cluster name '$CLUSTER_NAME' is invalid"
    echo "Cluster name must contain only letters and numbers (no spaces, hyphens, or special characters)"
    exit 1
fi

# Validate required environment variables
validate_env_vars

echo "Installing OKD cluster with name: $CLUSTER_NAME (OKD version: $OKD_VERSION)"

# Create a work directory for installing the OKD cluster
rm -rf $BASE_DIR/clusters/$CLUSTER_NAME
mkdir -p $BASE_DIR/clusters/$CLUSTER_NAME
cd $BASE_DIR/clusters/$CLUSTER_NAME

# Download the OKD installer
INSTALLER_URL=$(get_okd_installer_url "$OKD_VERSION")

echo "Downloading OKD installer from: $INSTALLER_URL"
curl -sS -L -o openshift-install.tar.gz https://github.com/okd-project/okd/releases/download/4.19.0-okd-scos.6/openshift-install-linux-4.19.0-okd-scos.6.tar.gz

# Unpack the installer
echo "Unpacking OKD installer"
tar xfz openshift-install.tar.gz

# Create the install-config.yaml file (from template)
echo "Creating install-config.yaml from template with environment variable substitution"
export CLUSTER_NAME
envsubst < $BASE_DIR/templates/okd/$OKD_VERSION/install-config.yaml > $BASE_DIR/clusters/$CLUSTER_NAME/install-config.yaml

# Install the cluster
./openshift-install create cluster --log-level=info

# Generate a TLS cert for the cluster
cd $BASE_DIR
./generate-tls-cert.sh --clusterName $CLUSTER_NAME

# Update the cluster's default ingress to use the cert
CERT_DIR=./certificates/$CLUSTER_NAME
kubectl create secret tls apicurio-tls-cert \
  --cert=$CERT_DIR/fullchain.pem \
  --key=$CERT_DIR/privkey.pem \
  -n openshift-ingress
kubectl patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type=merge \
  -p '{"spec":{"defaultCertificate":{"name":"apicurio-tls-cert"}}}'
