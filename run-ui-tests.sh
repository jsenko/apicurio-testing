#!/bin/bash

# Parse command line arguments
CLUSTER_NAME=""
NAMESPACE=""
APPLICATION_NAME=""
APICURIO_REGISTRY_VERSION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --appName)
            APPLICATION_NAME="$2"
            shift 2
            ;;
        --clusterName)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --version)
            APICURIO_REGISTRY_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
            echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$APPLICATION_NAME" ]; then
    echo "Error: --appName argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: --clusterName argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

if [ -z "$APICURIO_REGISTRY_VERSION" ]; then
    echo "Error: --version argument is required"
    echo "Usage: $0 --appName <application_name> --clusterName <cluster_name> --namespace <namespace> --version <registry_version>"
    echo "Example: $0 --appName my-application-name --clusterName okd419 --namespace testns1 --version 3.0.9"
    exit 1
fi

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export APPLICATION_NAME
export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export APICURIO_REGISTRY_VERSION
export NAMESPACE
export BASE_DOMAIN="apicurio-testing.org"
export APPS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/apps"
export APP_DIR="$APPS_DIR/$APPLICATION_NAME"
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"
export APP_INGRESS_URL="registry-app.$NAMESPACE.$APPS_URL"
export UI_INGRESS_URL="registry-ui.$NAMESPACE.$APPS_URL"
export TESTS_DIR="$APP_DIR/tests"
export UI_TESTS_DIR="$TESTS_DIR/ui"
export TOOLS_DIR="$BASE_DIR/tools"

mkdir -p $UI_TESTS_DIR
cd $UI_TESTS_DIR

# Clone the apicurio-registry repository
echo "Cloning apicurio-registry git repository at branch/tag: $APICURIO_REGISTRY_VERSION"
git clone --branch $APICURIO_REGISTRY_VERSION --depth 1 https://github.com/Apicurio/apicurio-registry.git

# Prepare to run the UI tests
echo "Preparing to run tests (npm install)."
cd apicurio-registry/ui/tests

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

npm install
npx playwright install --with-deps
npm run test
