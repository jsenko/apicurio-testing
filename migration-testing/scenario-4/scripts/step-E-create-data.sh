#!/bin/bash

# Step C: Create Test Data
#
# This script:
# 1. Builds the artifact-creator application (if needed)
# 2. Runs the artifact-creator to populate the registry
# 3. Saves the creation summary

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log and data directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

LOG_FILE="$PROJECT_DIR/logs/step-C-create-data.log"
SUMMARY_FILE="$PROJECT_DIR/data/creation-summary.txt"

# Registry URL (via nginx)
REGISTRY_URL="${REGISTRY_URL:-https://localhost:8443/apis/registry/v2}"
echo "Registry URL: $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if Registry is accessible
echo "[1/4] Checking registry accessibility..." | tee -a "$LOG_FILE"
if ! curl -f -s -k "$REGISTRY_URL/system/info" > /dev/null 2>&1; then
    echo "❌ Registry is not accessible at $REGISTRY_URL" | tee -a "$LOG_FILE"
    echo "   Make sure registry is running (steps A and B completed)" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ Registry is accessible" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if JAR exists
echo "[2/4] Checking artifact-creator JAR..." | tee -a "$LOG_FILE"
JAR_PATH="$PROJECT_DIR/clients/artifact-creator/target/artifact-creator-1.0.0-SNAPSHOT.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo "❌ artifact-creator JAR not found at $JAR_PATH" | tee -a "$LOG_FILE"
    echo "   Please run build-clients.sh first or use run-scenario-4.sh" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ artifact-creator JAR found" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run artifact creator
echo "[3/4] Running artifact-creator..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR/clients/artifact-creator"

# SSL/TLS truststore configuration (combined truststore with both Registry and Keycloak certs)
TRUSTSTORE_PATH="$PROJECT_DIR/certs/client-truststore.jks"
TRUSTSTORE_PASSWORD="registry123"

# OIDC authentication configuration
AUTH_SERVER_URL="https://localhost:9443/realms/registry/protocol/openid-connect/token"

CLIENT_ID="developer-client"
CLIENT_SECRET="test1"

java -Djavax.net.ssl.trustStore="$TRUSTSTORE_PATH" \
     -Djavax.net.ssl.trustStorePassword="$TRUSTSTORE_PASSWORD" \
     -Dapicurio.auth.server.url="$AUTH_SERVER_URL" \
     -Dapicurio.auth.client.id="$CLIENT_ID" \
     -Dapicurio.auth.client.secret="$CLIENT_SECRET" \
     -jar target/artifact-creator-1.0.0-SNAPSHOT.jar \
     "$REGISTRY_URL" \
     "$SUMMARY_FILE" \
     2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "" | tee -a "$LOG_FILE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "[4/4] Verifying creation summary..." | tee -a "$LOG_FILE"
    if [ -f "$SUMMARY_FILE" ]; then
        echo "  ✓ Creation summary saved" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        echo "Summary:" | tee -a "$LOG_FILE"
        cat "$SUMMARY_FILE" | tee -a "$LOG_FILE"
    else
        echo "  ⚠ Creation summary file not found" | tee -a "$LOG_FILE"
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "Test data has been created in the registry" | tee -a "$LOG_FILE"
    echo "Summary: $SUMMARY_FILE" | tee -a "$LOG_FILE"
    echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
else
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Check the log for details: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    exit 1
fi
