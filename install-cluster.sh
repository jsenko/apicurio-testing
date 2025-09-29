#!/bin/bash

# Script to install OKD cluster
# Usage: ./install-cluster.sh [--cluster <cluster-name>]

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secrets.env if it exists
if [[ -f "$BASE_DIR/secrets.env" ]]; then
    echo "Sourcing environment variables from secrets.env..."
    source "$BASE_DIR/secrets.env"
fi

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
    echo "Usage: $0 [--cluster <cluster-name>] [--okdVersion <okd-version>] [--region <aws-region>] [--computeNodes <count>] [--controlPlaneNodes <count>] [--baseDomain <domain>] [--debug] [--force]"
    echo ""
    echo "Optional Parameters:"
    echo "  --cluster <cluster-name>     Name of the cluster to install (default: $USER)"
    echo "                               Must contain only letters and numbers"
    echo ""
    echo "Optional Parameters:"
    echo "  --okdVersion <version>       OKD version to install (default: 4.19)"
    echo "  --region <aws-region>        AWS region to deploy to (default: us-east-1)"
    echo "  --computeNodes <count>       Number of compute/worker nodes (default: 3)"
    echo "  --controlPlaneNodes <count>  Number of control plane/master nodes (default: 3)"
    echo "  --baseDomain <domain>        Base domain name for the cluster (default: apicurio-testing.org)"
    echo "  --debug                     Enable debug logging for openshift-install"
    echo "  --force                     Force deletion of existing cluster directory (DANGEROUS: Might delete live cluster metadata!)"
    echo "  -h, --help                   Show this help message"
    exit 1
}

# Initialize variables
CLUSTER_NAME="$USER"
OKD_VERSION="4.19"
REGION="us-east-1"
COMPUTE_NODES="3"
CONTROL_PLANE_NODES="3"
BASE_DOMAIN="apicurio-testing.org"
DEBUG="false"
FORCE="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --okdVersion)
            OKD_VERSION="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --computeNodes)
            COMPUTE_NODES="$2"
            shift 2
            ;;
        --controlPlaneNodes)
            CONTROL_PLANE_NODES="$2"
            shift 2
            ;;
        --baseDomain)
            BASE_DOMAIN="$2"
            shift 2
            ;;
        --debug)
            DEBUG="true"
            shift 1
            ;;
        --force)
            FORCE="true"
            shift 1
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

# Validate cluster name (should not be empty after defaulting to $USER)
if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: cluster name is empty (default: \$USER)"
    usage
fi

# Validate cluster name format (only letters and numbers allowed)
if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Cluster name '$CLUSTER_NAME' is invalid"
    echo "Cluster name must contain only letters and numbers (no spaces, hyphens, or special characters)"
    exit 1
fi

# Validate node count parameters
if [[ ! "$COMPUTE_NODES" =~ ^[0-9]+$ ]] || [[ "$COMPUTE_NODES" -lt 0 ]]; then
    echo "Error: --computeNodes must be a non-negative integer"
    exit 1
fi

if [[ ! "$CONTROL_PLANE_NODES" =~ ^[0-9]+$ ]] || [[ "$CONTROL_PLANE_NODES" -lt 1 ]]; then
    echo "Error: --controlPlaneNodes must be a positive integer (minimum 1)"
    exit 1
fi

# Validate that control plane nodes is odd number for HA
if [[ "$CONTROL_PLANE_NODES" -gt 1 ]] && [[ $((CONTROL_PLANE_NODES % 2)) -eq 0 ]]; then
    echo "Warning: Control plane nodes should be an odd number for proper HA quorum (1, 3, 5, etc.)"
    echo "You specified $CONTROL_PLANE_NODES control plane nodes."
fi

# Validate base domain format (basic domain validation)
if [[ ! "$BASE_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    echo "Error: Base domain '$BASE_DOMAIN' is not a valid domain name format"
    echo "Domain names should contain only letters, numbers, dots, and hyphens"
    exit 1
fi

# Set AWS_DEFAULT_REGION to the region (either default or provided via --region)
export AWS_DEFAULT_REGION="$REGION"
echo "Using AWS region: $REGION"

# Validate required environment variables
validate_env_vars

echo "Installing OKD cluster with name: $CLUSTER_NAME (OKD version: $OKD_VERSION)"
echo "Cluster configuration: $CONTROL_PLANE_NODES control plane nodes, $COMPUTE_NODES compute nodes"
echo "Using base domain: $BASE_DOMAIN"
CLUSTER_DIR=$BASE_DIR/clusters/$CLUSTER_NAME

# Check if cluster directory already exists and handle it safely
if [[ -d "$CLUSTER_DIR" ]]; then
    echo "Warning: Cluster directory '$CLUSTER_DIR' already exists!"
    echo "This may contain state from a live cluster."

    if [[ "$FORCE" != "true" ]]; then
        echo ""
        echo "Error: Refusing to delete existing cluster directory without explicit confirmation."
        echo "To proceed and DELETE the existing cluster directory, re-run with --force flag:"
        echo "  $0 --cluster $CLUSTER_NAME --force"
        echo ""
        echo "WARNING: Using --force will permanently delete the existing cluster metadata!"
        echo "Make sure the cluster is properly destroyed before using --force."
        exit 1
    else
        echo "Force flag detected. Removing existing cluster directory..."
        rm -rf "$CLUSTER_DIR"
    fi
fi

# Create a work directory for installing the OKD cluster
mkdir -p $CLUSTER_DIR
cd $CLUSTER_DIR || exit 1

# Download the OKD installer
INSTALLER_URL=$(get_okd_installer_url "$OKD_VERSION")

if [[ $? -ne 0 ]] || [[ -z "$INSTALLER_URL" ]]; then
    echo "Error: Failed to get installer URL for OKD version $OKD_VERSION"
    exit 1
fi

echo "Downloading OKD installer from: $INSTALLER_URL"
curl -sS -L -o openshift-install.tar.gz "$INSTALLER_URL"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download OKD installer"
    exit 1
fi

# Save the installer URL to a file for later use by destroy script
echo "$INSTALLER_URL" > installer-url.txt
echo "Saved installer URL to installer-url.txt"

# Unpack the installer
echo "Unpacking OKD installer"
tar xfz openshift-install.tar.gz

# Create the install-config.yaml file (from template)
echo "Creating install-config.yaml from template with environment variable substitution"
export CLUSTER_NAME
export REGION
export COMPUTE_NODES
export CONTROL_PLANE_NODES
export BASE_DOMAIN
envsubst < $BASE_DIR/templates/okd/$OKD_VERSION/install-config.yaml > $CLUSTER_DIR/install-config.yaml

# Install the cluster
if [[ "$DEBUG" == "true" ]]; then
    ./openshift-install create cluster --log-level=debug
else
    ./openshift-install create cluster
fi

# Generate a TLS cert for the cluster
cd $BASE_DIR || exit 1
./generate-tls-cert.sh --cluster $CLUSTER_NAME

# Update the cluster's default ingress to use the cert
export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig
CERT_DIR=./certificates/$CLUSTER_NAME
kubectl create secret tls apicurio-tls-cert \
  --cert=$CERT_DIR/fullchain.pem \
  --key=$CERT_DIR/privkey.pem \
  -n openshift-ingress
kubectl patch ingresscontroller default \
  -n openshift-ingress-operator \
  --type=merge \
  -p '{"spec":{"defaultCertificate":{"name":"apicurio-tls-cert"}}}'
