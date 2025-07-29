#!/bin/bash

# Script to destroy OKD cluster
# Usage: ./destroy-cluster.sh --cluster <cluster-name>

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

# Function to ensure openshift-install binary is available
ensure_installer() {
    local cluster_dir="$1"
    
    # Check if openshift-install binary already exists
    if [[ -f "$cluster_dir/openshift-install" ]]; then
        echo "OpenShift installer already present"
        return 0
    fi
    
    echo "OpenShift installer not found, attempting to download..."
    
    # Check if installer-url.txt exists
    if [[ ! -f "$cluster_dir/installer-url.txt" ]]; then
        echo "Error: installer-url.txt not found in cluster directory"
        echo "This file should have been created during cluster installation"
        echo "Cannot proceed without knowing which installer version to download"
        exit 1
    fi
    
    # Read the installer URL from the file
    local installer_url
    installer_url=$(cat "$cluster_dir/installer-url.txt")
    
    if [[ -z "$installer_url" ]]; then
        echo "Error: installer-url.txt is empty"
        exit 1
    fi
    
    echo "Downloading OpenShift installer from: $installer_url"
    
    # Download the installer
    curl -sS -L -o "$cluster_dir/openshift-install.tar.gz" "$installer_url"
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to download OpenShift installer"
        exit 1
    fi
    
    # Extract the installer
    cd "$cluster_dir"
    echo "Extracting OpenShift installer"
    tar xfz openshift-install.tar.gz
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to extract OpenShift installer"
        exit 1
    fi
    
    # Verify the installer was extracted successfully
    if [[ ! -f "$cluster_dir/openshift-install" ]]; then
        echo "Error: openshift-install binary not found after extraction"
        exit 1
    fi
    
    echo "OpenShift installer downloaded and extracted successfully"
}

# Function to display usage
usage() {
    echo "Usage: $0 --cluster <cluster-name>"
    echo "  --cluster       Name of the cluster to install"
    exit 1
}

# Initialize variables
CLUSTER_NAME=""
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

# Validate required parameters
if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Error: --cluster parameter is required"
    usage
fi

# Validate required environment variables
validate_env_vars

echo "Destroying OKD cluster with name: $CLUSTER_NAME"

# Define cluster directory
CLUSTER_DIR=$BASE_DIR/clusters/$CLUSTER_NAME

# Check if cluster directory exists
if [[ ! -d "$CLUSTER_DIR" ]]; then
    echo "Error: Cluster directory '$CLUSTER_DIR' does not exist"
    echo "Cannot destroy a cluster that was never installed"
    exit 1
fi

# Change to cluster directory
cd "$CLUSTER_DIR"

# Ensure the openshift-install binary is available
ensure_installer "$CLUSTER_DIR"

# Destroy the cluster
./openshift-install destroy cluster --log-level=info
