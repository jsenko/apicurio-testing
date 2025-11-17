#!/bin/bash

# Step F: Export Data from Registry v2
#
# This script:
# 1. Connects to the v2 registry admin API
# 2. Exports all registry data (artifacts, versions, metadata, rules)
# 3. Saves the export as a .zip file
# 4. Verifies the export was successful

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log and data directories
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data"

LOG_FILE="$PROJECT_DIR/logs/step-F-export-v2-data.log"
EXPORT_FILE="$PROJECT_DIR/data/registry-v2-export.zip"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step F: Export Data from Registry v2" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Registry URL (direct to v2, not through nginx)
REGISTRY_URL="${REGISTRY_URL:-http://localhost:2222}"
EXPORT_ENDPOINT="$REGISTRY_URL/apis/registry/v2/admin/export"

echo "Registry URL: $REGISTRY_URL" | tee -a "$LOG_FILE"
echo "Export File:  $EXPORT_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Check if Registry is accessible
echo "[1/4] Checking registry accessibility..." | tee -a "$LOG_FILE"
if ! curl -f -s "$REGISTRY_URL/apis/registry/v2/system/info" > /dev/null 2>&1; then
    echo "❌ Registry is not accessible at $REGISTRY_URL" | tee -a "$LOG_FILE"
    echo "   Make sure registry v2 is running" | tee -a "$LOG_FILE"
    exit 1
fi
echo "  ✓ Registry is accessible" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Remove old export file if it exists
if [ -f "$EXPORT_FILE" ]; then
    echo "[2/4] Removing old export file..." | tee -a "$LOG_FILE"
    rm -f "$EXPORT_FILE"
    echo "  ✓ Old export file removed" | tee -a "$LOG_FILE"
else
    echo "[2/4] No old export file to remove" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Export data from registry
echo "[3/4] Exporting data from registry v2..." | tee -a "$LOG_FILE"
echo "  Calling: $EXPORT_ENDPOINT" | tee -a "$LOG_FILE"

# Use curl to download the export zip file
HTTP_CODE=$(curl -w "%{http_code}" -o "$EXPORT_FILE" -s "$EXPORT_ENDPOINT")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "  ✓ Export completed successfully (HTTP $HTTP_CODE)" | tee -a "$LOG_FILE"
else
    echo "  ✗ Export failed (HTTP $HTTP_CODE)" | tee -a "$LOG_FILE"
    if [ -f "$EXPORT_FILE" ]; then
        echo "  Response:" | tee -a "$LOG_FILE"
        cat "$EXPORT_FILE" | tee -a "$LOG_FILE"
        rm -f "$EXPORT_FILE"
    fi
    exit 1
fi
echo "" | tee -a "$LOG_FILE"

# Verify export file
echo "[4/4] Verifying export file..." | tee -a "$LOG_FILE"

if [ ! -f "$EXPORT_FILE" ]; then
    echo "  ✗ Export file not found: $EXPORT_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

FILE_SIZE=$(ls -lh "$EXPORT_FILE" | awk '{print $5}')
FILE_SIZE_BYTES=$(stat -c%s "$EXPORT_FILE" 2>/dev/null || stat -f%z "$EXPORT_FILE" 2>/dev/null)

if [ "$FILE_SIZE_BYTES" -lt 100 ]; then
    echo "  ✗ Export file is too small ($FILE_SIZE)" | tee -a "$LOG_FILE"
    echo "  Content:" | tee -a "$LOG_FILE"
    cat "$EXPORT_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "  ✓ Export file created: $EXPORT_FILE" | tee -a "$LOG_FILE"
echo "  ✓ File size: $FILE_SIZE ($FILE_SIZE_BYTES bytes)" | tee -a "$LOG_FILE"

# Check if it's a valid zip file
if command -v unzip &> /dev/null; then
    if unzip -t "$EXPORT_FILE" > /dev/null 2>&1; then
        echo "  ✓ Valid ZIP file format" | tee -a "$LOG_FILE"

        # List contents
        echo "" | tee -a "$LOG_FILE"
        echo "  ZIP file contents:" | tee -a "$LOG_FILE"
        unzip -l "$EXPORT_FILE" | tee -a "$LOG_FILE"
    else
        echo "  ✗ Invalid ZIP file format" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    echo "  ⚠ unzip command not available, skipping ZIP validation" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✓ Step F completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry v2 data exported successfully" | tee -a "$LOG_FILE"
echo "Export file: $EXPORT_FILE" | tee -a "$LOG_FILE"
echo "File size:   $FILE_SIZE" | tee -a "$LOG_FILE"
echo "Log:         $LOG_FILE" | tee -a "$LOG_FILE"
