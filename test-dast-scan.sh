#!/bin/bash

# Function to display usage information
show_usage() {
    echo "Usage: $0 --url <dast-url> --version <dast-version>"
    echo ""
    echo "This script runs RapiDAST (Rapid DAST) security scanning against a deployed application."
    echo ""
    echo "Arguments:"
    echo "  --url           Required. The URL of the running application"
    echo "  --version       Optional. The version of RapiDAST to run"
}

# Parse command line arguments
DAST_BASE_URL="https://registry-api.dev.apicur.io"
RAPIDAST_TAG="development"

while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            DAST_BASE_URL="$2"
            shift 2
            ;;
        --version)
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
if [ -z "$DAST_BASE_URL" ]; then
    echo "Error: --url argument is required"
    show_usage
    exit 1
fi

# Get the directory where this script is located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAST_TESTS_DIR="$BASE_DIR/dast-tests"

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
export DAST_BASE_URL
envsubst < $BASE_DIR/templates/rapidast/registry_v3_unauthenticated.yaml > $DAST_TESTS_DIR/rapidast-config.yaml
CONFIG_FILENAME=$DAST_TESTS_DIR/rapidast-config.yaml
RESULTS_DIR=$DAST_TESTS_DIR/results

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
echo "RapiDAST version: $RAPIDAST_TAG"
echo "Configuration file: $CONFIG_FILENAME"
echo "Application URL: $DAST_BASE_URL"
echo "--"
echo "RapiDAST configuration file:"
echo "------------------------------------"
cat $CONFIG_FILENAME
echo "------------------------------------"
echo ""
echo "------------------------------------"
echo "Running RapiDAST DAST Security Scan..."
echo "------------------------------------"

# Run rapidast with the provided configuration
# $PYTHON_CMD rapidast.py --config "$CONFIG_FILENAME"

mkdir $RESULTS_DIR
docker run \
  -v $CONFIG_FILENAME:/opt/rapidast/config/config.yaml:Z \
  -v $RESULTS_DIR:/opt/rapidast/results/:Z,U \
  quay.io/redhatproductsecurity/rapidast:latest

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
