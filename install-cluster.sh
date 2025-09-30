#!/bin/bash

# Script to install OKD cluster
# Usage: ./install-cluster.sh [--cluster <cluster-name>]

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/shared.sh"

load_cache_config

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
    echo    "Usage: $0 [--cluster <cluster-name>] [--okdVersion <okd-version>] [--region <aws-region>] [--computeNodes <count>] [--controlPlaneNodes <count>] [--baseDomain <domain>] [--log-level <level>] [--force]"
    echo    ""
    echo    "Optional Parameters:"
    echo    "  --cluster <cluster-name>     Name of the cluster to install (default: $USER)"
    echo    "                               Must contain only letters and numbers"
    echo    ""
    echo    "Optional Parameters:"
    echo    "  --okdVersion <version>       OKD version to install (default: 4.19)"
    echo    "  --region <aws-region>        AWS region to deploy to (default: us-east-1)"
    echo    "  --computeNodes <count>       Number of compute/worker nodes (default: 3)"
    echo    "  --controlPlaneNodes <count>  Number of control plane/master nodes (default: 3)"
    echo    "  --baseDomain <domain>        Base domain name for the cluster (default: apicurio-testing.org)"
    echo -e "  --log-level <level>          Log level for openshift-install (default: info). ${LIGHT_PURPLE}Use warn log level in CI to avoid leaking admin password.${NO_COLOR}"
    echo -e "  --force                     Force deletion of existing cluster directory. ${LIGHT_PURPLE}Might delete live cluster metadata.${NO_COLOR}"
    echo    "  -h, --help                   Show this help message"
    exit 1
}

# Initialize variables
CLUSTER_NAME="$USER"
OKD_VERSION="4.19"
REGION="us-east-1"
COMPUTE_NODES="3"
CONTROL_PLANE_NODES="3"
BASE_DOMAIN="apicurio-testing.org"
LOG_LEVEL="info"
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
        --log-level)
            LOG_LEVEL="$2"
            shift 2
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
CLUSTER_DIR=$CLUSTERS_DIR/$CLUSTER_NAME

# Check if cluster directory already exists and handle it safely
if [[ -d "$CLUSTER_DIR" ]]; then
    echo "Warning: Cluster directory '$CLUSTER_DIR' already exists!"
    echo "It might contain state from a live cluster."

    if [[ "$FORCE" != "true" ]]; then
        echo ""
        echo "To proceed and DELETE the existing cluster directory, re-run with --force flag:"
        echo "  $0 --cluster $CLUSTER_NAME --force"
        echo ""
        echo "Warning: Make sure the cluster has been properly destroyed before using --force."
        exit 1
    else
        echo "Force flag detected. Removing existing cluster directory..."
        rm -rf "$CLUSTER_DIR"
    fi
fi

# Create a work directory for installing the OKD cluster
mkdir -p $CLUSTER_DIR
cd $CLUSTER_DIR || exit 1

"$BASE_DIR/download-okd-installer.sh" --version "$OKD_VERSION"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to download openshift-install for OKD version $OKD_VERSION."
    exit 1
fi
OPENSHIFT_INSTALLER="$BIN_DIR/$OKD_VERSION/openshift-install"

# Create the install-config.yaml file (from template)
echo "Creating install-config.yaml from template with environment variable substitution"
export CLUSTER_NAME
export REGION
export COMPUTE_NODES
export CONTROL_PLANE_NODES
export BASE_DOMAIN
envsubst < $BASE_DIR/templates/okd/$OKD_VERSION/install-config.yaml > $CLUSTER_DIR/install-config.yaml

echo -n "$OKD_VERSION" > "$CLUSTER_DIR/version"
# Install the cluster
$OPENSHIFT_INSTALLER create cluster --log-level="$LOG_LEVEL"

# Generate a TLS cert for the cluster
cd $BASE_DIR || exit 1
./install-tls-cert.sh --cluster $CLUSTER_NAME
