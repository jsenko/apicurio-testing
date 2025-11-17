#!/bin/bash

# Step J: Validate Post-Migration State
#
# This script:
# 1. Uses artifact-validator-v2 to validate the v3 registry (testing backward compatibility)
# 2. Runs the validator against nginx (which routes to v3)
# 3. Saves the validation report
# 4. Exits with error if validation fails
#
# Note: This validates that v3 registry maintains backward compatibility with v2 clients

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log and data directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

LOG_FILE="$PROJECT_DIR/logs/step-J-validate-post-migration.log"
REPORT_FILE="$PROJECT_DIR/data/validation-report-post-migration.txt"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step J: Validate Post-Migration State" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Registry URL (via nginx, using v2 API against v3 registry)
REGISTRY_URL="${REGISTRY_URL:-https://localhost:8443/apis/registry/v2}"
echo "Registry URL: $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "Note: Using v2 client to test backward compatibility" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if Registry is accessible
echo "[1/4] Checking registry accessibility..." | tee -a "$LOG_FILE"
if ! curl -f -s -k "https://localhost:8443/apis/registry/v2/system/info" > /dev/null 2>&1; then
    echo "❌ Registry v2 API is not accessible at https://localhost:8443" | tee -a "$LOG_FILE"
    echo "   Make sure nginx is routing to v3 (step-I-switch-nginx-to-v3.sh)" | tee -a "$LOG_FILE"
    echo "   and that v3 supports v2 API backward compatibility" | tee -a "$LOG_FILE"
    exit 1
fi

# Verify we're actually talking to v3
V3_VERSION=$(curl -s -k "https://localhost:8443/apis/registry/v3/system/info" | jq -r '.version' 2>/dev/null || echo "unknown")
echo "  ✓ Registry is accessible (v3 version: $V3_VERSION)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if JAR exists
echo "[2/4] Checking artifact-validator-v2 JAR..." | tee -a "$LOG_FILE"
JAR_PATH="$PROJECT_DIR/clients/artifact-validator-v2/target/artifact-validator-v2-1.0.0-SNAPSHOT.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo "❌ artifact-validator-v2 JAR not found at $JAR_PATH" | tee -a "$LOG_FILE"
    echo "   Please run build-clients.sh first or use run-scenario-3.sh" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ artifact-validator-v2 JAR found" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run artifact validator
echo "[3/4] Running artifact-validator-v2 against v3 registry..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR/clients/artifact-validator-v2"

# SSL/TLS truststore configuration
TRUSTSTORE_PATH="$PROJECT_DIR/certs/registry-truststore.jks"
TRUSTSTORE_PASSWORD="registry123"

java -Djavax.net.ssl.trustStore="$TRUSTSTORE_PATH" \
     -Djavax.net.ssl.trustStorePassword="$TRUSTSTORE_PASSWORD" \
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
    echo "  ✓ Step J completed successfully - ALL VALIDATIONS PASSED" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Post-migration state validated successfully" | tee -a "$LOG_FILE"
    echo "Backward compatibility confirmed: v2 client works with v3 registry" | tee -a "$LOG_FILE"
    echo "Report: $REPORT_FILE" | tee -a "$LOG_FILE"
    echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
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
    echo "  ✗ Step J completed with VALIDATION FAILURES" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Some validations failed - check the report for details" | tee -a "$LOG_FILE"
    echo "Report: $REPORT_FILE" | tee -a "$LOG_FILE"
    echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
else
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "  ✗ Step J failed with error" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Check the log for details: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 2
fi
