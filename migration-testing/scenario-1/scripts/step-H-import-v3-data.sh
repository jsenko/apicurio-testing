#!/bin/bash

# Step H: Import Data into Registry v3
#
# This script:
# 1. Checks that the export file exists
# 2. Connects to the v3 registry admin API
# 3. Imports all registry data from the .zip file
# 4. Verifies the import was successful

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

LOG_FILE="$PROJECT_DIR/logs/step-H-import-v3-data.log"
EXPORT_FILE="$PROJECT_DIR/data/registry-v2-export.zip"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step H: Import Data into Registry v3" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Registry URL (direct to v3, not through nginx)
REGISTRY_URL="${REGISTRY_V3_URL:-http://localhost:3333}"
IMPORT_ENDPOINT="$REGISTRY_URL/apis/registry/v3/admin/import"

echo "Registry URL: $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "Import File:  $EXPORT_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if export file exists
echo "[1/4] Checking export file..." | tee -a "$LOG_FILE"
if [ ! -f "$EXPORT_FILE" ]; then
    echo "❌ Export file not found: $EXPORT_FILE" | tee -a "$LOG_FILE"
    echo "   Run step-F-export-v2-data.sh first" | tee -a "$LOG_FILE"
    exit 1
fi

FILE_SIZE=$(ls -lh "$EXPORT_FILE" | awk '{print $5}')
echo "  ✓ Export file exists: $FILE_SIZE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if Registry v3 is accessible
echo "[2/4] Checking registry v3 accessibility..." | tee -a "$LOG_FILE"
if ! curl -f -s "$REGISTRY_URL/apis/registry/v3/system/info" > /dev/null 2>&1; then
    echo "❌ Registry v3 is not accessible at $REGISTRY_URL" | tee -a "$LOG_FILE"
    echo "   Make sure registry v3 is running (step-G-deploy-v3.sh)" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ Registry v3 is accessible" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Import data into registry
echo "[3/4] Importing data into registry v3..." | tee -a "$LOG_FILE"
echo "  Calling: $IMPORT_ENDPOINT" | tee -a "$LOG_FILE"

# Use curl to upload the export zip file
# The import endpoint expects a multipart/form-data POST with the file
HTTP_CODE=$(curl -w "%{http_code}" -o /tmp/import-response.txt -s \
    -X POST \
    -H "Content-Type: application/zip" \
    --data-binary "@$EXPORT_FILE" \
    "$IMPORT_ENDPOINT")

if [ "$HTTP_CODE" -eq 204 ] || [ "$HTTP_CODE" -eq 200 ]; then
    echo "  ✓ Import completed successfully (HTTP $HTTP_CODE)" | tee -a "$LOG_FILE"
else
    echo "  ✗ Import failed (HTTP $HTTP_CODE)" | tee -a "$LOG_FILE"
    if [ -f /tmp/import-response.txt ]; then
        echo "  Response:" | tee -a "$LOG_FILE"
        cat /tmp/import-response.txt | tee -a "$LOG_FILE"
    fi
    exit 1
fi
echo "" | tee -a "$LOG_FILE"

# Verify import by checking artifact count
echo "[4/4] Verifying imported data..." | tee -a "$LOG_FILE"

# Give the registry a moment to process the import
sleep 2

# Check system info
SYSTEM_INFO=$(curl -s "$REGISTRY_URL/apis/registry/v3/system/info")
echo "  Registry info:" | tee -a "$LOG_FILE"
echo "$SYSTEM_INFO" | jq '.' 2>&1 | tee -a "$LOG_FILE"

# Search for artifacts to verify import
SEARCH_URL="$REGISTRY_URL/apis/registry/v3/search/artifacts?limit=1000"
SEARCH_RESULT=$(curl -s "$SEARCH_URL")

ARTIFACT_COUNT=$(echo "$SEARCH_RESULT" | jq -r '.count' 2>/dev/null || echo "0")

echo "" | tee -a "$LOG_FILE"
echo "  Found $ARTIFACT_COUNT artifacts in registry" | tee -a "$LOG_FILE"

# We expect 25 artifacts from the v2 export
EXPECTED_COUNT=25
if [ "$ARTIFACT_COUNT" -eq "$EXPECTED_COUNT" ]; then
    echo "  ✓ Artifact count matches expected: $ARTIFACT_COUNT" | tee -a "$LOG_FILE"
elif [ "$ARTIFACT_COUNT" -gt 0 ]; then
    echo "  ⚠ Artifact count is $ARTIFACT_COUNT (expected $EXPECTED_COUNT)" | tee -a "$LOG_FILE"
else
    echo "  ✗ No artifacts found - import may have failed" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✓ Step H completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry v3 data imported successfully" | tee -a "$LOG_FILE"
echo "Artifacts imported: $ARTIFACT_COUNT" | tee -a "$LOG_FILE"
echo "Registry URL:       $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "Log:                $LOG_FILE" | tee -a "$LOG_FILE"

# Cleanup temp file
rm -f /tmp/import-response.txt
