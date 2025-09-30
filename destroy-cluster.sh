#!/bin/bash

# Script to destroy OKD cluster
# Usage: ./destroy-cluster.sh [--cluster <cluster-name>]

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

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

# Function to display usage
usage() {
    echo "Usage: $0 [--cluster <cluster-name>]"
    echo "  --cluster       Name of the cluster to destroy (default: \$USER)"
    exit 1
}

# Initialize variables
CLUSTER_NAME="$USER"
OKD_VERSION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
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

# Validate cluster name (should not be empty after defaulting to $USER)
if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: cluster name is empty (default: \$USER)"
    usage
fi

# Validate required environment variables
validate_env_vars

echo "Destroying OKD cluster with name: $CLUSTER_NAME"

load_cluster_config "$CLUSTER_NAME"

# Change to cluster directory
cd "$CLUSTER_DIR"

# Ensure the openshift-install binary is available
OKD_VERSION=$(cat "$CLUSTER_DIR/version")
"$BASE_DIR/download-okd-installer.sh" --version "$OKD_VERSION"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download openshift-install for OKD version $OKD_VERSION."
    exit 1
fi
OPENSHIFT_INSTALLER="$BIN_DIR/$OKD_VERSION/openshift-install"

# Destroy the cluster
$OPENSHIFT_INSTALLER destroy cluster --log-level=info

# Clean up local ./clusters directory
rm -rf $CLUSTER_DIR
