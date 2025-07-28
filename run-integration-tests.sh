#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 --cluster <cluster_name> --namespace <namespace> [--tag <registry_tag>] [--testProfile <profile>] [--registryProtocol <protocol>] [--registryHost <host>] [--registryPort <port>] [--realmName <realm>]"
    echo ""
    echo "This script runs the apicurio-registry integration tests against a deployed Registry instance."
    echo "The Registry URL is constructed as: http://registry-app-NAMESPACE.apps.CLUSTER_NAME.apicurio-testing.org"
    echo ""
    echo "Arguments:"
    echo "  --cluster           Required. The OpenShift cluster name"
    echo "  --namespace         Required. The namespace where Registry is deployed"
    echo "  --tag               Optional. Git branch/tag to test against (default: main)"
    echo "  --testProfile       Optional. Test profile to run (default: all). Allowed values: all, smoke, auth"
    echo "  --registryProtocol  Optional. Registry protocol (default: http)"
    echo "  --registryHost      Optional. Registry host (default: registry-app-NAMESPACE.apps.CLUSTER_NAME.apicurio-testing.org)"
    echo "  --registryPort      Optional. Registry port (default: 80)"
    echo "  --realmName         Optional. Keycloak realm name (default: registry)"
    echo ""
    echo "Example: $0 --cluster okd419 --namespace testns1 --tag main --testProfile smoke"
    echo "Example: $0 --cluster okd419 --namespace testns1 --registryProtocol https --registryPort 443 --realmName myrealm"
}

# Parse command line arguments
CLUSTER_NAME=""
NAMESPACE=""
APICURIO_REGISTRY_TAG="main"
TEST_PROFILE="all"
REGISTRY_PROTOCOL=""
REGISTRY_HOST=""
REGISTRY_PORT=""
REALM_NAME=""

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
        --testProfile)
            TEST_PROFILE="$2"
            shift 2
            ;;
        --registryProtocol)
            REGISTRY_PROTOCOL="$2"
            shift 2
            ;;
        --registryHost)
            REGISTRY_HOST="$2"
            shift 2
            ;;
        --registryPort)
            REGISTRY_PORT="$2"
            shift 2
            ;;
        --realmName)
            REALM_NAME="$2"
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
    echo "Error: --cluster argument is required"
    show_usage
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    echo "Error: --namespace argument is required"
    show_usage
    exit 1
fi

if [ -z "$TEST_PROFILE" ]; then
    TEST_PROFILE=all
    exit 1
fi

# Validate the test profile value
if [[ "$TEST_PROFILE" != "all" && "$TEST_PROFILE" != "smoke" && "$TEST_PROFILE" != "auth" ]]; then
    echo "Error: Invalid testProfile value '$TEST_PROFILE'. Allowed values are: all, smoke, auth"
    show_usage
    exit 1
fi

if [ -z "$REGISTRY_PROTOCOL" ]; then
    REGISTRY_PROTOCOL=http
fi

if [ -z "$REGISTRY_HOST" ]; then
    REGISTRY_HOST=
fi

if [ -z "$REGISTRY_PORT" ]; then
    REGISTRY_PORT=80
fi

if [ -z "$REALM_NAME" ]; then
    REALM_NAME=registry
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
export REGISTRY_PROTOCOL
if [ -z "$REGISTRY_HOST" ]; then
    REGISTRY_HOST=registry-app-$NAMESPACE.$APPS_URL
fi
export REGISTRY_HOST
export REGISTRY_PORT
export REALM_NAME
export REGISTRY_URL="$REGISTRY_PROTOCOL://$REGISTRY_HOST"
export KEYCLOAK_HOST="keycloak-$NAMESPACE.$APPS_URL"

export TOKEN_AUTH_URL="https://$KEYCLOAK_HOST/realms/$REALM_NAME/protocol/openid-connect/token"

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
echo "Running Integration Tests ($TEST_PROFILE profile)..."
echo "------------------------------------"

# Run the integration tests
./mvnw verify -am --no-transfer-progress \
    -Pintegration-tests \
    -P$TEST_PROFILE \
    -pl integration-tests \
    -Dmaven.javadoc.skip=true \
    -Dquarkus.oidc.token-path=$TOKEN_AUTH_URL \
    -Dquarkus.http.test-protocol=$REGISTRY_PROTOCOL \
    -Dquarkus.http.test-host=$REGISTRY_HOST \
    -Dquarkus.http.test-port=$REGISTRY_PORT

echo ""
echo "Integration tests completed."
