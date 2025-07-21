#!/bin/bash

# Script to destroy a namespace in a Kubernetes cluster
# Usage: ./destroy-namespace.sh --clusterName <cluster-name> --namespace <namespace>

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage
usage() {
    echo "Usage: $0 --clusterName <cluster-name> --namespace <namespace>"
    echo ""
    echo "Required Parameters:"
    echo "  --clusterName <cluster-name>    Name of the cluster containing the namespace"
    echo "  --namespace <namespace>         Name of the namespace to delete"
    echo ""
    echo "Optional Parameters:"
    echo "  -h, --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --clusterName okd419 --namespace test-namespace"
    echo "  $0 --clusterName cluster1 --namespace apicurio-registry"
    echo ""
    echo "Notes:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    echo "  - This will permanently delete the namespace and all resources within it"
    exit 1
}

# Initialize variables
CLUSTER_NAME=""
NAMESPACE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clusterName)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
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
    echo "Namespace must contain only letters, numbers, and hyphens"
    exit 1
fi

# Set up cluster directory path
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

echo "Destroying namespace '$NAMESPACE' in cluster '$CLUSTER_NAME'"

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Warning: Namespace '$NAMESPACE' does not exist in cluster '$CLUSTER_NAME'"
    echo "Nothing to delete."
    exit 0
fi

# Show resources in the namespace before deletion
echo "Resources in namespace '$NAMESPACE':"
kubectl get all -n "$NAMESPACE" 2>/dev/null || echo "No resources found or unable to list resources"
echo ""

# Delete the namespace
echo "Deleting namespace '$NAMESPACE'..."
kubectl delete namespace "$NAMESPACE"

if [[ $? -eq 0 ]]; then
    echo "Successfully deleted namespace '$NAMESPACE' from cluster '$CLUSTER_NAME'"
else
    echo "Error: Failed to delete namespace '$NAMESPACE'"
    exit 1
fi
