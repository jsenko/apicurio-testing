#!/bin/bash

# Script to configure Docker registry pull secret for a namespace
# Usage: ./configure-pull-secret.sh --cluster <cluster-name> --namespace <namespace>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "Usage: $0 --cluster <cluster-name> --namespace <namespace> [--secretName <name>]"
    echo ""
    echo "Required Parameters:"
    echo "  --cluster <cluster-name>    Name of the cluster to configure"
    echo "  --namespace <namespace>     Name of the namespace to configure"
    echo ""
    echo "Optional Parameters:"
    echo "  --secretName <name>         Name of the docker registry secret (default: 'docker-registry-secret')"
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
    echo "  $0 --cluster okd419 --namespace test-namespace"
    echo ""
    echo "  export DOCKER_SERVER=registry.redhat.io"
    echo "  export DOCKER_USERNAME=myrhuser"
    echo "  export DOCKER_PASSWORD=mytoken"
    echo "  export DOCKER_EMAIL=myrhuser@redhat.com"
    echo "  $0 --cluster cluster1 --namespace apicurio-registry --secretName my-registry-secret"
    echo ""
    echo "Notes:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    echo "  - The namespace will be created automatically if it doesn't exist"
    echo "  - This will create a docker-registry secret (default name: 'docker-registry-secret')"
    echo "  - The secret will be attached to the default service account in the namespace"
    echo "  - If the secret already exists, it will be updated with new credentials"
    exit 1
}

# Initialize variables
CLUSTER_NAME=""
NAMESPACE=""
SECRET_NAME=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --secretName)
            SECRET_NAME="$2"
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

if [[ -z "$NAMESPACE" ]]; then
    echo "Error: --namespace parameter is required"
    usage
fi

# Validate cluster name format (only letters and numbers allowed)
if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Cluster name '$CLUSTER_NAME' is invalid"
    echo "Cluster name must contain only letters and numbers (no spaces, hyphens, or special characters)"
    exit 1
fi

# Validate namespace format (only letters and numbers allowed)
if [[ ! "$NAMESPACE" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo "Error: Namespace '$NAMESPACE' is invalid"
    echo "Namespace must contain only letters and numbers (no spaces, hyphens, or special characters)"
    exit 1
fi

# Set default secret name if not provided
if [[ -z "$SECRET_NAME" ]]; then
    SECRET_NAME="docker-registry-secret"
    echo "No secret name specified, using default: $SECRET_NAME"
fi

# Validate required environment variables
validate_env_vars

# Set up cluster and directory paths
CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"

# Check if cluster directory exists
if [[ ! -d "$CLUSTER_DIR" ]]; then
    echo "Error: Cluster directory '$CLUSTER_DIR' does not exist"
    echo "Make sure the cluster '$CLUSTER_NAME' has been created"
    exit 1
fi

# Check if kubeconfig exists
if [[ ! -f "$CLUSTER_DIR/auth/kubeconfig" ]]; then
    echo "Error: Kubeconfig file '$CLUSTER_DIR/auth/kubeconfig' does not exist"
    echo "Make sure the cluster '$CLUSTER_NAME' has been properly configured"
    exit 1
fi

# Set up kubectl auth
export KUBECONFIG="$CLUSTER_DIR/auth/kubeconfig"

echo "Configuring Docker registry pull secret for cluster '$CLUSTER_NAME' in namespace '$NAMESPACE'"
echo "Secret name: $SECRET_NAME"
echo "Docker server: $DOCKER_SERVER"
echo "Docker username: $DOCKER_USERNAME"
echo "Docker email: $DOCKER_EMAIL"

# Create the namespace if it doesn't exist
echo "Checking if namespace '$NAMESPACE' exists..."
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Namespace '$NAMESPACE' already exists, skipping creation"
else
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create namespace '$NAMESPACE'"
        exit 1
    fi
fi

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE', deleting it first..."
    kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
fi

# Create the docker registry secret
echo "Creating Docker registry secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl create secret docker-registry "$SECRET_NAME" \
    --docker-server="$DOCKER_SERVER" \
    --docker-username="$DOCKER_USERNAME" \
    --docker-password="$DOCKER_PASSWORD" \
    --docker-email="$DOCKER_EMAIL" \
    --namespace="$NAMESPACE"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create Docker registry secret"
    exit 1
fi

echo "Successfully created Docker registry secret '$SECRET_NAME'"

# Check if default service account exists
echo "Checking if default service account exists in namespace '$NAMESPACE'..."
if ! kubectl get serviceaccount default -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Error: Default service account does not exist in namespace '$NAMESPACE'"
    echo "This is unusual - the default service account should exist automatically"
    exit 1
fi

# Attach the secret to the default service account
echo "Attaching secret '$SECRET_NAME' to default service account in namespace '$NAMESPACE'..."

# Get current imagePullSecrets from the default service account
CURRENT_SECRETS=$(kubectl get serviceaccount default -n "$NAMESPACE" -o jsonpath='{.imagePullSecrets[*].name}' 2>/dev/null || echo "")

# Check if our secret is already attached
if echo "$CURRENT_SECRETS" | grep -q "$SECRET_NAME"; then
    echo "Secret '$SECRET_NAME' is already attached to the default service account"
else
    # Patch the service account to add the imagePullSecret
    kubectl patch serviceaccount default -n "$NAMESPACE" -p "{\"imagePullSecrets\":[{\"name\":\"$SECRET_NAME\"}]}" --type=merge
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to attach secret to default service account"
        exit 1
    fi
    
    echo "Successfully attached secret '$SECRET_NAME' to default service account"
fi

# Verify the configuration
echo ""
echo "Verification:"
echo "============="

# Show the service account with imagePullSecrets
echo "Default service account with imagePullSecrets:"
kubectl get serviceaccount default -n "$NAMESPACE" -o yaml | grep -A 10 imagePullSecrets || echo "No imagePullSecrets found"

echo ""
echo "Configuration completed successfully!"
echo ""
echo "The Docker registry secret '$SECRET_NAME' has been created in namespace '$NAMESPACE'"
echo "and attached to the default service account. Pods in this namespace will now be able"
echo "to pull images from the configured Docker registry."
