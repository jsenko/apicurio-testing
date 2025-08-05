#!/bin/bash

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ##################################################
# Function to display usage information
# ##################################################
show_usage() {
    echo "Usage: $0 --cluster <cluster_name> --version <registry_version> [OPTIONS]"
    echo ""
    echo "REQUIRED PARAMETERS:"
    echo "  --cluster <name>         Name of the OpenShift cluster where Apicurio Registry Operator will be installed"
    echo "  --version <version>      Version of Apicurio Registry Operator to install (e.g., 3.0.9)"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  -h, --help               Display this help message and exit"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic operator installation:"
    echo "  $0 --cluster okd419 --version 3.0.9"
    echo ""
    echo ""
    echo "NOTES:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
    echo "  - This script installs the Apicurio Registry Operator cluster-wide"
}

# Parse command line arguments
CLUSTER_NAME=""
APICURIO_REGISTRY_VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --version)
            APICURIO_REGISTRY_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set default values
OPERATOR_NAMESPACE="apicurio-registry-operator"

# Check if required arguments are provided
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --cluster argument is required"
    show_usage
    exit 1
fi

if [ -z "$APICURIO_REGISTRY_VERSION" ]; then
    echo "Error: --version argument is required"
    show_usage
    exit 1
fi

# Set up environment variables
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export APICURIO_REGISTRY_VERSION
export APICURIO_OPERATOR_YAML="$BASE_DIR/templates/registry-operator/$APICURIO_REGISTRY_VERSION/apicurio-registry-operator.yaml"

# Check if cluster directory exists
if [ ! -d "$CLUSTER_DIR" ]; then
    echo "Error: Cluster directory '$CLUSTER_DIR' does not exist"
    echo "Make sure the cluster '$CLUSTER_NAME' has been created"
    exit 1
fi

# Check if kubeconfig exists
if [ ! -f "$CLUSTER_DIR/auth/kubeconfig" ]; then
    echo "Error: Kubeconfig file '$CLUSTER_DIR/auth/kubeconfig' does not exist"
    echo "Make sure the cluster '$CLUSTER_NAME' has been properly configured"
    exit 1
fi

# Check if operator YAML template exists
if [ ! -f "$APICURIO_OPERATOR_YAML" ]; then
    echo "Error: Operator YAML template '$APICURIO_OPERATOR_YAML' does not exist"
    echo "Make sure version '$APICURIO_REGISTRY_VERSION' is available in templates/registry-operator/"
    exit 1
fi

cd $CLUSTER_DIR

# Set up kubectl auth
export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig

# Create the namespace if it doesn't exist
echo "Creating namespace: $OPERATOR_NAMESPACE (if it doesn't exist)"
kubectl create namespace $OPERATOR_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy the Apicurio Registry operator to the namespace
echo "Using Apicurio Registry Operator YAML from: $APICURIO_OPERATOR_YAML"
export OPERATOR_NAMESPACE
envsubst < "$APICURIO_OPERATOR_YAML" > $CLUSTER_DIR/apicurio-registry-operator.yaml
echo "Installing Apicurio Registry Operator into namespace $OPERATOR_NAMESPACE"
kubectl apply -f $CLUSTER_DIR/apicurio-registry-operator.yaml -n $OPERATOR_NAMESPACE

echo "Apicurio Registry Operator installation completed successfully!"
echo "Operator installed in namespace: $OPERATOR_NAMESPACE"
echo "Operator YAML saved to: $CLUSTER_DIR/apicurio-registry-operator.yaml"
