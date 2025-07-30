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

# Install ZAP if not already available
install_zap() {
    echo "Checking for ZAP installation..."
    
    # Check if ZAP is already available on PATH
    if command -v zap.sh &> /dev/null || command -v zap &> /dev/null; then
        echo "ZAP is already installed and available on PATH"
        return 0
    fi
    
    # Check if ZAP is already installed in our local directory
    if [ -f "$DAST_TESTS_DIR/ZAP_2.16.1/zap.sh" ]; then
        echo "ZAP found in local directory, adding to PATH"
        export PATH="$DAST_TESTS_DIR/ZAP_2.16.1:$PATH"
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
    export PATH="$DAST_TESTS_DIR/ZAP_${ZAP_VERSION}:$PATH"
    
    echo "ZAP ${ZAP_VERSION} installed successfully"
    
    # Verify installation
    if command -v zap.sh &> /dev/null; then
        echo "ZAP is now available on PATH"
    else
        echo "Warning: ZAP may not be properly configured on PATH"
    fi
}


# Install ZAP
install_zap

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

mkdir $RESULTS_DIR

# Create the virtual environment
echo "Creating the virtual environment"
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Install requirements
echo "Installing requirements"
pip install -U pip
pip install -r requirements.txt

# Run rapidast with the provided configuration
$PYTHON_CMD rapidast.py --config "$CONFIG_FILENAME"

# docker run \
#   -v $CONFIG_FILENAME:/opt/rapidast/config/config.yaml:Z \
#   -v $RESULTS_DIR:/opt/rapidast/results/:Z \
#   --user $(id -u):$(id -g) \
#   -e JAVA_TOOL_OPTIONS="-Djava.util.prefs.userRoot=/tmp/.java" \
#   quay.io/redhatproductsecurity/rapidast:latest

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
