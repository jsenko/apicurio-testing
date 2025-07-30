#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 --cluster <cluster_name> --namespace <namespace> --config <config_file> [--tag <rapidast_tag>]"
    echo ""
    echo "This script runs RapiDAST (Rapid DAST) security scanning against a deployed application."
    echo "The target application URL should be configured in the provided rapidast YAML configuration file."
    echo ""
    echo "Arguments:"
    echo "  --cluster           Required. The OpenShift cluster name"
    echo "  --namespace         Required. The namespace where the target application is deployed"
    echo "  --config            Required. Path to the rapidast YAML configuration file"
    echo "  --tag               Optional. Git branch/tag of rapidast to use (default: development)"
    echo ""
    echo "Example: $0 --cluster okd419 --namespace testns1 --config /path/to/rapidast-config.yaml"
    echo "Example: $0 --cluster okd419 --namespace testns1 --config ./dast-config.yaml --tag 2.12.1"
}

# Parse command line arguments
CLUSTER_NAME=""
NAMESPACE=""
CONFIG_FILE=""
RAPIDAST_TAG="development"

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
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --tag)
            RAPIDAST_TAG="$2"
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

if [ -z "$CONFIG_FILE" ]; then
    echo "Error: --config argument is required"
    show_usage
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' does not exist"
    exit 1
fi

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CLUSTER_NAME
export CLUSTER_DIR="$BASE_DIR/clusters/$CLUSTER_NAME"
export RAPIDAST_TAG
export NAMESPACE
export BASE_DOMAIN="apicurio-testing.org"
export TESTS_DIR="$CLUSTER_DIR/namespaces/$NAMESPACE/tests"
export DAST_TESTS_DIR="$TESTS_DIR/dast"
export APPS_URL="apps.$CLUSTER_NAME.$BASE_DOMAIN"

# Common application URLs that might be useful for rapidast configuration
export REGISTRY_APP_URL="registry-app-$NAMESPACE.$APPS_URL"
export REGISTRY_UI_URL="registry-ui-$NAMESPACE.$APPS_URL"
export KEYCLOAK_URL="keycloak-$NAMESPACE.$APPS_URL"

mkdir -p $DAST_TESTS_DIR
cd $DAST_TESTS_DIR

# Clone the rapidast repository
echo "Cloning rapidast git repository at branch/tag: $RAPIDAST_TAG"
if [ -d "rapidast" ]; then
    echo "Repository already exists, removing and re-cloning..."
    rm -rf rapidast
fi
git clone --branch $RAPIDAST_TAG --depth 1 https://github.com/RedHatProductSecurity/rapidast.git

# Change to the repository directory
cd rapidast

# Copy the configuration file to the rapidast directory
CONFIG_FILENAME=$(basename "$CONFIG_FILE")
echo "Copying configuration file: $CONFIG_FILE -> $CONFIG_FILENAME"
cp "$CONFIG_FILE" "$CONFIG_FILENAME"

# Check if Python 3.12+ is available
if ! command -v python3.12 &> /dev/null; then
    if ! command -v python3 &> /dev/null; then
        echo "Error: Python 3 is required but not found. Please install Python 3.12 or later."
        exit 1
    else
        PYTHON_CMD="python3"
        echo "Warning: python3.12 not found, using python3. RapiDAST requires Python 3.12+."
    fi
else
    PYTHON_CMD="python3.12"
fi

# Install dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "Installing rapidast dependencies..."
    $PYTHON_CMD -m pip install --user -r requirements.txt
fi

# Display some diagnostic info
echo ""
echo "RapiDAST DAST Scan Info:"
echo "--"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo "RapiDAST version: $RAPIDAST_TAG"
echo "Configuration file: $CONFIG_FILENAME"
echo "Available application URLs:"
echo "  Registry App: http://$REGISTRY_APP_URL"
echo "  Registry UI: http://$REGISTRY_UI_URL"
echo "  Keycloak: https://$KEYCLOAK_URL"
echo "--"
echo ""
echo "------------------------------------"
echo "Running RapiDAST DAST Security Scan..."
echo "------------------------------------"

# Run rapidast with the provided configuration
$PYTHON_CMD rapidast.py --config "$CONFIG_FILENAME"

RAPIDAST_EXIT_CODE=$?

echo ""
if [ $RAPIDAST_EXIT_CODE -eq 0 ]; then
    echo "RapiDAST DAST scan completed successfully."
    echo ""
    echo "Results are available in the 'results/' directory:"
    if [ -d "results" ]; then
        find results -type f -name "*.html" -o -name "*.json" -o -name "*.xml" -o -name "*.sarif" | head -10
        if [ $(find results -type f | wc -l) -gt 10 ]; then
            echo "... and more files in results/"
        fi
    fi
else
    echo "RapiDAST DAST scan failed with exit code: $RAPIDAST_EXIT_CODE"
    exit $RAPIDAST_EXIT_CODE
fi
