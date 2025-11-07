#!/bin/bash

# Script to configure Docker registry pull secret
# Usage: ./configure-pull-secret.sh [--cluster <cluster-name>]

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
    
    if [[ -z "${DOCKER_SERVER:-}" ]]; then
        missing_vars+=("DOCKER_SERVER")
    fi
    
    if [[ -z "${DOCKER_USERNAME:-}" ]]; then
        missing_vars+=("DOCKER_USERNAME")
    fi
    
    if [[ -z "${DOCKER_PASSWORD:-}" ]]; then
        missing_vars+=("DOCKER_PASSWORD")
    fi
    
    if [[ -z "${DOCKER_EMAIL:-}" ]]; then
        missing_vars+=("DOCKER_EMAIL")
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
    echo ""
    echo "Optional Parameters:"
    echo "  --cluster <cluster-name>    Name of the cluster to configure (default: \$USER)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Required Environment Variables:"
    echo "  DOCKER_SERVER               Docker registry server (e.g., docker.io, registry.redhat.io)"
    echo "  DOCKER_USERNAME             Docker registry username"
    echo "  DOCKER_PASSWORD             Docker registry password or token"
    echo "  DOCKER_EMAIL                Docker registry email address"
    echo ""
    echo "Examples:"
    echo "  export DOCKER_SERVER=docker.io"
    echo "  export DOCKER_USERNAME=myuser"
    echo "  export DOCKER_PASSWORD=mypassword"
    echo "  export DOCKER_EMAIL=myuser@example.com"
    echo "  $0                        # Uses default cluster (\$USER)"
    echo "  $0 --cluster ocp416       # Uses specific cluster"
    echo ""
    echo "Notes:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    exit 1
}

# Initialize variables
CLUSTER_NAME="$USER"

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

# Validate cluster name format (only letters and numbers allowed)
if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Cluster name '$CLUSTER_NAME' is invalid"
    echo "Cluster name must contain only letters and numbers (no spaces, hyphens, or special characters)"
    exit 1
fi

# Validate required environment variables
validate_env_vars

load_cluster_config "$CLUSTER_NAME"

echo "Configuring Docker registry pull secret for cluster '$CLUSTER_NAME'"
echo "Docker server: $DOCKER_SERVER"
echo "Docker username: $DOCKER_USERNAME"
echo "Docker email: $DOCKER_EMAIL"

rm -rf $CLUSTER_DIR/.docker
rm -f $CLUSTER_DIR/pull-secret.json
rm -f $CLUSTER_DIR/config.json
rm -f $CLUSTER_DIR/merged-config.json
rm -f $CLUSTER_DIR/pull-secret-updated.json

# Login to the docker container registry
export DOCKER_CONFIG="$CLUSTER_DIR/.docker"
echo "$DOCKER_PASSWORD" | docker login $DOCKER_SERVER -u $DOCKER_USERNAME --password-stdin
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to login to Docker with configured credentials"
    exit 1
fi

# Export the current global pull secret to a local file
echo "Getting the global pull secret from OpenShift..."
kubectl get secret pull-secret -n openshift-config -o json > $CLUSTER_DIR/pull-secret.json
echo "Decoding pull secret into OpenShift config.json..."
cat $CLUSTER_DIR/pull-secret.json | jq -r '.data[".dockerconfigjson"]' | base64 -d > $CLUSTER_DIR/config.json

# Merge the two docker configs (global from OpenShift and config from docker login above)
echo "Merging new pull secret into existing OpenShift global config..."
jq -s 'reduce .[] as $item ({}; .auths += ($item.auths // {}))' $CLUSTER_DIR/config.json $CLUSTER_DIR/.docker/config.json > $CLUSTER_DIR/merged-config.json

# Encode the new config.json and update the pull-secret.json file with the new content
ENCODED_CONFIG=$(cat $CLUSTER_DIR/merged-config.json | base64 -w0)
jq --arg newcontent "$ENCODED_CONFIG" '.data.".dockerconfigjson" = $newcontent' $CLUSTER_DIR/pull-secret.json > $CLUSTER_DIR/pull-secret-updated.json

# Update the global pull secret now that it has been configured
echo "Updating OpenShift config pull secret..."
kubectl replace -f $CLUSTER_DIR/pull-secret-updated.json
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update global pull secret"
    exit 1
fi

# Clean up temporary files and files with secrets
rm -rf $CLUSTER_DIR/.docker
rm -f $CLUSTER_DIR/pull-secret.json
rm -f $CLUSTER_DIR/config.json
rm -f $CLUSTER_DIR/merged-config.json
rm -f $CLUSTER_DIR/pull-secret-updated.json


echo ""
echo "Configuration completed successfully!"
echo ""
echo "The Docker registry credentials have been configured in the global OpenShift config"
echo "Pods in all namespaces will now be able to pull images from the configured Docker registry."
