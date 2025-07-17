#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 --clusterName <cluster_name> --namespace <namespace> [--tag <registry_tag>]"
    echo "Example: $0 --clusterName okd419 --namespace testns1 --tag main"
    echo ""
    echo "This script runs the apicurio-registry integration tests against a deployed Registry instance."
    echo "The Registry URL is constructed as: http://registry-app-NAMESPACE.apps.CLUSTER_NAME.apicurio-testing.org"
    echo ""
    echo "Arguments:"
    echo "  --clusterName    Required. The OpenShift cluster name"
    echo "  --namespace      Required. The namespace where Registry is deployed"
    echo "  --tag            Optional. Git branch/tag to test against (default: main)"
}

# Parse command line arguments
CLUSTER_NAME=""
NAMESPACE=""
APICURIO_REGISTRY_TAG="main"

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
        --tag)
            APICURIO_REGISTRY_TAG="$2"
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

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export APICURIO_REGISTRY_TAG
export NAMESPACE
export BASE_DOMAIN="apicurio-testing.org"
export TESTS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/tests"
export INTEGRATION_TESTS_DIR="$TESTS_DIR/integration"
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"
export REGISTRY_HOST=registry-app-$NAMESPACE.$APPS_URL
export REGISTRY_PORT=80
export REGISTRY_URL="http://$REGISTRY_HOST"

mkdir -p $INTEGRATION_TESTS_DIR
cd $INTEGRATION_TESTS_DIR

# Clone the apicurio-registry repository
echo "Cloning apicurio-registry git repository at branch/tag: $APICURIO_REGISTRY_TAG"
if [ -d "apicurio-registry" ]; then
    echo "Repository already exists, removing and re-cloning..."
    rm -rf apicurio-registry
fi
git clone --branch $APICURIO_REGISTRY_TAG --depth 1 https://github.com/Apicurio/apicurio-registry.git

# Change to the repository directory
cd apicurio-registry

# Display some diagnostic info
echo ""
echo "Registry System Info:"
echo "--"
curl -s $REGISTRY_URL/apis/registry/v3/system/info | jq
echo "--"
echo ""
echo "Registry URL: $REGISTRY_URL"
echo "Testing against Registry version: $APICURIO_REGISTRY_TAG"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo ""
echo "------------------------------------"
echo "Running Integration Tests (ci profile)..."
echo "------------------------------------"

# Run the integration tests with the ci profile
# Based on the GitHub workflow, the command structure is:
# ./mvnw verify -am --no-transfer-progress -Pintegration-tests -Pci -pl integration-tests -Dmaven.javadoc.skip=true
# We need to configure it to use the external Registry URL instead of starting a local instance

./mvnw verify -am --no-transfer-progress \
    -Pintegration-tests \
    -Pci \
    -pl integration-tests \
    -Dmaven.javadoc.skip=true \
    -Dquarkus.http.test-host=$REGISTRY_HOST \
    -Dquarkus.http.test-port=$REGISTRY_PORT

echo ""
echo "Integration tests completed."
