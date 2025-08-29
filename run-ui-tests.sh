#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 [--cluster <cluster_name>] --namespace <namespace> --tag <registry_tag> [--isDownstream <true|false>]"
    echo ""
    echo "This script runs the apicurio-registry UI tests against a deployed Registry instance."
    echo "The Registry UI URL is constructed as: http://registry-ui-NAMESPACE.apps.CLUSTER_NAME.apicurio-testing.org"
    echo ""
    echo "Arguments:"
    echo "  --cluster <cluster_name>     Name of the cluster where the registry is deployed (default: \$USER)"
    echo "  --namespace <namespace>      Kubernetes namespace where the registry is running"
    echo "  --tag <registry_tag>         Git branch or tag of the apicurio-registry repository to test"
    echo "  --isDownstream <true|false>  Whether this is a downstream build (optional, default: false)"
    echo "  -h, --help                   Show this help message and exit"
    echo ""
    echo "Example: $0 --cluster okd419 --namespace testns1 --tag 3.0.9 --isDownstream true"
}

# Parse command line arguments
CLUSTER_NAME="$USER"
NAMESPACE=""
APICURIO_REGISTRY_TAG="main"
IS_DOWNSTREAM="false"

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
        --tag)
            APICURIO_REGISTRY_TAG="$2"
            shift 2
            ;;
        --isDownstream)
            IS_DOWNSTREAM="$2"
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

# Validate cluster name (should not be empty after defaulting to $USER)
if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: cluster name is empty (default: \$USER)"
    show_usage
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    show_usage
    exit 1
fi

if [ -z "$APICURIO_REGISTRY_TAG" ]; then
    echo "Error: --tag argument is required"
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
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"
export APP_INGRESS_URL="registry-app-$NAMESPACE.$APPS_URL"
export UI_INGRESS_URL="registry-ui-$NAMESPACE.$APPS_URL"
export TESTS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/tests"
export UI_TESTS_DIR="$TESTS_DIR/ui"

mkdir -p $UI_TESTS_DIR
cd $UI_TESTS_DIR

# Clone the apicurio-registry repository
echo "Cloning apicurio-registry git repository at branch/tag: $APICURIO_REGISTRY_TAG"
git clone --branch $APICURIO_REGISTRY_TAG --depth 1 https://github.com/Apicurio/apicurio-registry.git

# Prepare to run the UI tests
echo "Preparing to run tests (npm install)."
cd apicurio-registry/ui/tests
npm install
npx playwright install --with-deps

# Display some diagnostic info and run the tests.
echo ""
echo "App System Info:"
echo "--"
curl -s http://$APP_INGRESS_URL/apis/registry/v3/system/info | jq
echo "--"
echo ""
echo "UI Config Info (Local):"
echo "--"
curl -s http://$UI_INGRESS_URL/config.js
echo "--"
echo ""
echo "UI Config Info (Remote):"
echo "--"
curl -s http://$APP_INGRESS_URL/apis/registry/v3/system/uiConfig | jq
echo "--"
echo ""
echo "UI Version Info:"
curl -s http://$UI_INGRESS_URL/version.js
echo ""
echo "---------------------------"
echo "Running Playwright tests..."
echo "---------------------------"

# Run the tests
export REGISTRY_UI_URL="http://$UI_INGRESS_URL"
export IS_DOWNSTREAM
npm run test

# Check if the npm test command succeeded
NPM_EXIT_CODE=$?
if [ $NPM_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "UI tests failed with exit code: $NPM_EXIT_CODE"
    exit $NPM_EXIT_CODE
fi

echo ""
echo "UI tests completed successfully."
