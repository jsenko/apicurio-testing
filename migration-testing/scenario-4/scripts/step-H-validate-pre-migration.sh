#!/bin/bash

# Step D: Validate Pre-Migration State
#
# This script:
# 1. Builds the artifact-validator-v2 application (if needed)
# 2. Runs the validator against the registry (using v2 API)
# 3. Saves the validation report
# 4. Exits with error if validation fails

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log and data directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

LOG_FILE="$PROJECT_DIR/logs/step-D-validate-pre-migration.log"
REPORT_FILE="$PROJECT_DIR/data/validation-report-pre-migration.txt"

# Registry URL (via nginx)
REGISTRY_URL="${REGISTRY_URL:-https://localhost:8443/apis/registry/v2}"
echo "Registry URL: $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if Registry is accessible
echo "[1/4] Checking registry accessibility..." | tee -a "$LOG_FILE"
if ! curl -f -s -k "$REGISTRY_URL/system/info" > /dev/null 2>&1; then
    echo "❌ Registry is not accessible at $REGISTRY_URL" | tee -a "$LOG_FILE"
    echo "   Make sure registry is running (steps A-C completed)" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ Registry is accessible" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if JAR exists
echo "[2/4] Checking artifact-validator-v2 JAR..." | tee -a "$LOG_FILE"
JAR_PATH="$PROJECT_DIR/clients/artifact-validator-v2/target/artifact-validator-v2-1.0.0-SNAPSHOT.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo "❌ artifact-validator-v2 JAR not found at $JAR_PATH" | tee -a "$LOG_FILE"
    echo "   Please run build-clients.sh first or use run-scenario-4.sh" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ artifact-validator-v2 JAR found" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run artifact validator
echo "[3/4] Running artifact-validator-v2..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR/clients/artifact-validator-v2"

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
     -jar target/artifact-validator-v2-1.0.0-SNAPSHOT.jar \
     "$REGISTRY_URL" \
     "$REPORT_FILE" \
     2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "" | tee -a "$LOG_FILE"

if [ $EXIT_CODE -eq 0 ]; then
    echo "[4/4] Verifying validation report..." | tee -a "$LOG_FILE"
    if [ -f "$REPORT_FILE" ]; then
        echo "  ✓ Validation report saved" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        echo "Report:" | tee -a "$LOG_FILE"
        cat "$REPORT_FILE" | tee -a "$LOG_FILE"
    else
        echo "  ⚠ Validation report file not found" | tee -a "$LOG_FILE"
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "Pre-migration state validated successfully" | tee -a "$LOG_FILE"
    echo "Report: $REPORT_FILE" | tee -a "$LOG_FILE"
    echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    exit 0
elif [ $EXIT_CODE -eq 1 ]; then
    echo "[4/4] Validation completed with failures..." | tee -a "$LOG_FILE"
    if [ -f "$REPORT_FILE" ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Report:" | tee -a "$LOG_FILE"
        cat "$REPORT_FILE" | tee -a "$LOG_FILE"
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "Some validations failed - check the report for details" | tee -a "$LOG_FILE"
    echo "Report: $REPORT_FILE" | tee -a "$LOG_FILE"
    echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    exit 1
else
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "Error detected!" | tee -a "$LOG_FILE"
    echo "Check the log for details: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    exit 2
fi
