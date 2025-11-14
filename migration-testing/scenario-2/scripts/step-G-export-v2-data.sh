#!/bin/bash

# Step G: Export Registry v2 Data
#
# This script:
# 1. Exports all data from Registry v2
# 2. Saves the export as a ZIP file
# 3. Validates the ZIP file contents

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
LOG_DIR="$PROJECT_DIR/logs"

# Create directories
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/step-G-export-v2-data.log"
EXPORT_FILE="$DATA_DIR/registry-v2-export.zip"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step G: Export Registry v2 Data"
log "================================================================"
log ""

# Check if Registry v2 is accessible
log "[1/4] Verifying Registry v2 is accessible..."
if ! curl -sf http://localhost:8080/apis/registry/v2/system/info > /dev/null 2>&1; then
    log "❌ Registry v2 is not accessible at http://localhost:8080"
    log "   Make sure nginx is routing to v2"
    exit 1
fi

VERSION=$(curl -s http://localhost:8080/apis/registry/v2/system/info | jq -r '.version')
log "✅ Registry v2 accessible (version: $VERSION)"
log ""

# Count artifacts before export
log "[2/4] Counting artifacts to export..."
ARTIFACT_COUNT=$(curl -s "http://localhost:8080/apis/registry/v2/search/artifacts?group=default" | jq -r '.count // 0')
log "  Artifacts to export: $ARTIFACT_COUNT"

if [ "$ARTIFACT_COUNT" -eq 0 ]; then
    log "⚠️  Warning: No artifacts found in registry"
    log "   This may indicate the producer hasn't run yet"
fi
log ""

# Export data
log "[3/4] Exporting data from Registry v2..."
log "  Export file: $EXPORT_FILE"

if curl -f -o "$EXPORT_FILE" \
    -H "Accept: application/zip" \
    "http://localhost:8080/apis/registry/v2/admin/export" 2>&1 | tee -a "$LOG_FILE"; then
    log "✅ Export completed successfully"
else
    log "❌ Export failed"
    exit 1
fi
log ""

# Validate export
log "[4/4] Validating export file..."
if [ ! -f "$EXPORT_FILE" ]; then
    log "❌ Export file not found: $EXPORT_FILE"
    exit 1
fi

FILE_SIZE=$(ls -lh "$EXPORT_FILE" | awk '{print $5}')
log "  File size: $FILE_SIZE"

# Check if file is a valid ZIP
if unzip -t "$EXPORT_FILE" > /dev/null 2>&1; then
    log "✅ Export file is a valid ZIP archive"
else
    log "❌ Export file is not a valid ZIP archive"
    exit 1
fi

# List contents
log ""
log "Export contents:"
unzip -l "$EXPORT_FILE" 2>&1 | tee -a "$LOG_FILE"
log ""

log "================================================================"
log "  ✅ Step G completed successfully"
log "================================================================"
log ""
log "Summary:"
log "  - Artifacts exported: $ARTIFACT_COUNT"
log "  - Export file: $EXPORT_FILE"
log "  - File size: $FILE_SIZE"
log ""
log "Next step: Deploy Registry v3 (step-H-deploy-v3-kafka.sh)"
log ""
log "Logs saved to: $LOG_FILE"
log ""
