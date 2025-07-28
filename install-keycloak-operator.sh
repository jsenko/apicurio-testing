#!/bin/bash

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ##################################################
# Function to display usage information
# ##################################################
show_usage() {
    echo "Usage: $0 --clusterName <cluster_name> --namespace <namespace> --keycloakVersion <version> [OPTIONS]"
    echo ""
    echo "REQUIRED PARAMETERS:"
    echo "  --clusterName <name>     Name of the OpenShift cluster where Keycloak will be installed"
    echo "  --namespace <namespace>  Kubernetes namespace to deploy Keycloak into"
    echo ""
    echo "OPTIONAL PARAMETERS:"
    echo "  -h, --help               Display this help message and exit"
    echo ""
    echo "EXAMPLES:"
    echo "  # Basic installation:"
    echo "  $0 --clusterName okd419 --namespace keycloak-ns"
    echo ""
    echo "NOTES:"
    echo "  - The cluster must already exist and be properly configured"
    echo "  - Kubeconfig file must be present at clusters/<cluster_name>/auth/kubeconfig"
}


# Parse command line arguments
CLUSTER_NAME=""
NAMESPACE=""

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

# Check if required arguments are provided
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --clusterName argument is required"
    show_usage
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    show_usage
    exit 1
fi

# Validate namespace contains only letters and numbers
if [[ ! "$NAMESPACE" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "Error: Namespace '$NAMESPACE' is invalid. It must contain only letters and numbers."
    show_usage
    exit 1
fi

# Export environment variables
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export NAMESPACE
export BASE_DOMAIN="apicurio-testing.org"
export APPS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/apps"
export APP_DIR="$APPS_DIR/keycloak-operator"
export OPERATOR_NAME="keycloak-operator"
export OPERATOR_CHANNEL="fast"
export CATALOG_SOURCE="community-operators"
export CATALOG_SOURCE_NAMESPACE="openshift-marketplace"
export SUBSCRIPTION_NAME="$OPERATOR_NAME-$NAMESPACE"
export WAIT_TIMEOUT_SECONDS=300  # Max time to wait for the operator to be ready

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
# Set up kubectl auth
export KUBECONFIG=$CLUSTER_DIR/auth/kubeconfig

mkdir -p $APP_DIR

cd $CLUSTER_DIR

# Create the namespace if it doesn't exist
echo "Checking if namespace '$NAMESPACE' exists..."
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Namespace '$NAMESPACE' already exists, skipping creation"
else
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

# Install all YAML files from the Keycloak Operator template directory
KEYCLOAK_TEMPLATE_DIR="$BASE_DIR/templates/keycloak-operator"
echo "Installing all Keycloak YAML files from template directory..."
for template_file in "$KEYCLOAK_TEMPLATE_DIR"/*.yaml; do
    if [ -f "$template_file" ]; then
        # Get the filename without the path
        filename=$(basename "$template_file")
        echo "Processing template: $filename"
        
        # Create the processed file in the app directory
        processed_file="$APP_DIR/$filename"
        envsubst < "$template_file" > "$processed_file"
        kubectl apply -f "$processed_file" -n $NAMESPACE
    fi
done

# Wait for the Keycloak Operator to be ready
echo "Waiting for ClusterServiceVersion to be created..."
SECONDS_WAITED=0
CSV_NAME=""
while [ $SECONDS_WAITED -lt $WAIT_TIMEOUT_SECONDS ]; do
  CSV_NAME=$(kubectl get subscription ${SUBSCRIPTION_NAME} -n ${NAMESPACE} -o jsonpath='{.status.installedCSV}' 2>/dev/null || echo "")
  if [[ -n "$CSV_NAME" ]]; then
    echo "Found ClusterServiceVersion: $CSV_NAME"
    break
  fi
  sleep 5
  SECONDS_WAITED=$((SECONDS_WAITED + 5))
done

if [[ -z "$CSV_NAME" ]]; then
  echo "ERROR: Timed out waiting for ClusterServiceVersion to be created."
  exit 1
fi

echo "Waiting for CSV '${CSV_NAME}' to reach 'Succeeded' phase..."
SECONDS_WAITED=0
while [ $SECONDS_WAITED -lt $WAIT_TIMEOUT_SECONDS ]; do
  PHASE=$(kubectl get csv "$CSV_NAME" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$PHASE" == "Succeeded" ]]; then
    echo "--"
    echo "Keycloak Operator is ready (CSV phase: Succeeded)."
    exit 0
  fi
  echo "Current CSV phase: $PHASE (waiting...)"
  sleep 5
  SECONDS_WAITED=$((SECONDS_WAITED + 5))
done

echo "ERROR: Timed out waiting for CSV '${CSV_NAME}' to reach 'Succeeded' phase."
exit 1
