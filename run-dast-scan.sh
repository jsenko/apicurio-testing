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


# Install ZAP if not already available
install_zap() {
    local dast_tests_dir="$1"

    echo "Checking for ZAP installation..."
    
    # Check if ZAP is already available on PATH
    if command -v zap.sh &> /dev/null || command -v zap &> /dev/null; then
        echo "ZAP is already installed and available on PATH"
        return 0
    fi
    
    # Check if ZAP is already installed in our local directory
    if [ -f "$dast_tests_dir/ZAP_2.16.1/zap.sh" ]; then
        echo "ZAP found in local directory, adding to PATH"
        export PATH="$dast_tests_dir/ZAP_2.16.1:$PATH"
        return 0
    fi
    
    echo "ZAP not found, downloading and installing..."
    
    # Download ZAP Linux package
    ZAP_VERSION="2.16.1"
    ZAP_DOWNLOAD_URL="https://github.com/zaproxy/zaproxy/releases/download/v${ZAP_VERSION}/ZAP_${ZAP_VERSION}_Linux.tar.gz"
    ZAP_ARCHIVE="ZAP_${ZAP_VERSION}_Linux.tar.gz"
    
    echo "Downloading ZAP from: $ZAP_DOWNLOAD_URL"
    if ! curl -L -o "$ZAP_ARCHIVE" "$ZAP_DOWNLOAD_URL"; then
        echo "Error: Failed to download ZAP"
        exit 1
    fi
    
    # Extract ZAP
    echo "Extracting ZAP..."
    if ! tar -xzf "$ZAP_ARCHIVE"; then
        echo "Error: Failed to extract ZAP archive"
        exit 1
    fi
    
    # Clean up archive
    rm -f "$ZAP_ARCHIVE"
    
    # Check if extraction was successful
    if [ ! -f "ZAP_${ZAP_VERSION}/zap.sh" ]; then
        echo "Error: ZAP installation failed - zap.sh not found"
        exit 1
    fi
    
    # Make zap.sh executable
    chmod +x "ZAP_${ZAP_VERSION}/zap.sh"
    
    # Add ZAP to PATH for this session
    export PATH="$dast_tests_dir/ZAP_${ZAP_VERSION}:$PATH"
    
    echo "ZAP ${ZAP_VERSION} installed successfully"
    
    # Verify installation
    if command -v zap.sh &> /dev/null; then
        echo "ZAP is now available on PATH"
    else
        echo "Warning: ZAP may not be properly configured on PATH"
    fi
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
export REGISTRY_APP_URL="http://registry-app-$NAMESPACE.$APPS_URL"
export REGISTRY_UI_URL="http://registry-ui-$NAMESPACE.$APPS_URL"

mkdir -p $DAST_TESTS_DIR
cd $DAST_TESTS_DIR

# Make sure ZAP is installed
install_zap $DAST_TESTS_DIR

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
export DAST_BASE_URL=$REGISTRY_APP_URL
RAPIDAST_CONFIG=$DAST_TESTS_DIR/rapidast-config.yaml
envsubst < $BASE_DIR/templates/rapidast/$CONFIG_FILE > $RAPIDAST_CONFIG

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

# Display some diagnostic info
echo ""
echo "RapiDAST DAST Scan Info:"
echo "--"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo "RapiDAST version: $RAPIDAST_TAG"
echo "Configuration file: $RAPIDAST_CONFIG"
echo "Available application URLs:"
echo "  Registry App: http://$REGISTRY_APP_URL"
echo "  Registry UI: http://$REGISTRY_UI_URL"
echo "  Keycloak: https://$KEYCLOAK_URL"
echo "--"
echo ""
echo "------------------------------------"
echo "Running RapiDAST DAST Security Scan..."
echo "------------------------------------"

# Create the virtual environment
echo "Creating the virtual environment"
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Install requirements
echo "Installing requirements"
pip install -U pip
pip install -r requirements.txt

# Run rapidast with the provided configuration
$PYTHON_CMD rapidast.py --config $RAPIDAST_CONFIG

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
