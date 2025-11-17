#!/bin/bash

# Step K: Validate V3 Registry Using Native V3 Client
#
# This script:
# 1. Uses artifact-validator-v3 to validate the v3 registry (using native v3 API)
# 2. Runs the validator against nginx (which routes to v3)
# 3. Saves the validation report
# 4. Exits with error if validation fails
#
# Note: This validates the v3 registry using the native v3 SDK

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log and data directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

LOG_FILE="$PROJECT_DIR/logs/step-K-validate-v3-native.log"
REPORT_FILE="$PROJECT_DIR/data/validation-report-v3-native.txt"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step K: Validate V3 Registry Using Native V3 Client" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Registry URL (via nginx, using v3 API)
REGISTRY_URL="${REGISTRY_URL:-http://localhost:8080/apis/registry/v3}"
echo "Registry URL: $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "Note: Using v3 native client to validate v3 registry" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if Registry is accessible
echo "[1/4] Checking registry accessibility..." | tee -a "$LOG_FILE"
if ! curl -f -s "http://localhost:8080/apis/registry/v3/system/info" > /dev/null 2>&1; then
    echo "❌ Registry v3 API is not accessible at http://localhost:8080" | tee -a "$LOG_FILE"
    echo "   Make sure nginx is routing to v3 (step-I-switch-nginx-to-v3.sh)" | tee -a "$LOG_FILE"
    exit 1
fi

# Get v3 version
V3_VERSION=$(curl -s "http://localhost:8080/apis/registry/v3/system/info" | jq -r '.version' 2>/dev/null || echo "unknown")
echo "  ✓ Registry is accessible (v3 version: $V3_VERSION)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if JAR exists, build if needed
echo "[2/4] Checking artifact-validator-v3 build..." | tee -a "$LOG_FILE"
JAR_PATH="$PROJECT_DIR/clients/artifact-validator-v3/target/artifact-validator-v3-1.0.0-SNAPSHOT.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo "  JAR not found, building artifact-validator-v3..." | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/build-clients.sh" 2>&1 | tee -a "$LOG_FILE"
    BUILD_EXIT_CODE=$?

    if [ $BUILD_EXIT_CODE -ne 0 ]; then
        echo "❌ Build failed with exit code $BUILD_EXIT_CODE" | tee -a "$LOG_FILE"
        exit 1
    fi

    if [ ! -f "$JAR_PATH" ]; then
        echo "❌ Build succeeded but JAR file not found" | tee -a "$LOG_FILE"
        exit 1
    fi
fi
echo "  ✓ artifact-validator-v3 JAR found" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run artifact validator
echo "[3/4] Running artifact-validator-v3 against v3 registry..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR/clients/artifact-validator-v3"

java -jar target/artifact-validator-v3-1.0.0-SNAPSHOT.jar \
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
    echo "  ✓ Step K completed successfully - ALL VALIDATIONS PASSED" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "V3 registry validated successfully using native v3 client" | tee -a "$LOG_FILE"
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
    echo "  ✗ Step K completed with VALIDATION FAILURES" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Some validations failed - check the report for details" | tee -a "$LOG_FILE"
    echo "Report: $REPORT_FILE" | tee -a "$LOG_FILE"
    echo "Log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
else
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "  ✗ Step K failed with error" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Check the log for details: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 2
fi
