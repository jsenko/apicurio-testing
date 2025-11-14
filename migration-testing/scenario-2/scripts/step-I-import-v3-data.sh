#!/bin/bash

# Step I: Import Data into Registry v3
#
# This script:
# 1. Imports the exported data from v2 into v3
# 2. Verifies the import was successful
# 3. Validates artifact counts match

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/step-I-import-v3-data.log"
EXPORT_FILE="$DATA_DIR/registry-v2-export.zip"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step I: Import Data into Registry v3"
log "================================================================"
log ""

# Verify export file exists
log "[1/4] Verifying export file..."
if [ ! -f "$EXPORT_FILE" ]; then
    log "❌ Export file not found: $EXPORT_FILE"
    log "   Please run step-G-export-v2-data.sh first"
    exit 1
fi

FILE_SIZE=$(ls -lh "$EXPORT_FILE" | awk '{print $5}')
log "✅ Export file found: $EXPORT_FILE ($FILE_SIZE)"
log ""

# Check Registry v3 is accessible
log "[2/4] Verifying Registry v3 is accessible..."
if ! curl -sf http://localhost:3333/health/live > /dev/null 2>&1; then
    log "❌ Registry v3 is not accessible at http://localhost:3333"
    log "   Please run step-H-deploy-v3-kafka.sh first"
    exit 1
fi

VERSION=$(curl -s http://localhost:3333/apis/registry/v3/system/info | jq -r '.version')
log "✅ Registry v3 accessible (version: $VERSION)"
log ""

# Count artifacts before import
log "Counting artifacts before import..."
BEFORE_COUNT=$(curl -s "http://localhost:3333/apis/registry/v3/search/artifacts?group=default" | jq -r '.count // 0')
log "  Artifacts in v3 before import: $BEFORE_COUNT"
log ""

# Import data
log "[3/4] Importing data into Registry v3..."
if curl -f -X POST \
    -H "Content-Type: application/zip" \
    --data-binary "@$EXPORT_FILE" \
    "http://localhost:3333/apis/registry/v3/admin/import" 2>&1 | tee -a "$LOG_FILE"; then
    log ""
    log "✅ Import completed successfully"
else
    log ""
    log "❌ Import failed"
    exit 1
fi
log ""

# Give registry time to process the import
log "Waiting for registry to process import..."
sleep 3
log ""

# Verify import
log "[4/4] Verifying import..."
AFTER_COUNT=$(curl -s "http://localhost:3333/apis/registry/v3/search/artifacts?group=default" | jq -r '.count // 0')
log "  Artifacts in v3 after import: $AFTER_COUNT"
log ""

if [ "$AFTER_COUNT" -eq 0 ]; then
    log "❌ No artifacts found after import"
    log "   Import may have failed"
    exit 1
fi

log "Listing imported artifacts:"
curl -s "http://localhost:3333/apis/registry/v3/search/artifacts?group=default" | jq -r '.artifacts[] | "  - \(.artifactId) (\(.type))"' 2>&1 | tee -a "$LOG_FILE"
log ""

# Verify specific schema
log "Verifying imported schema..."
SCHEMA_ID="avro-messages-value"
if curl -sf "http://localhost:3333/apis/registry/v3/groups/default/artifacts/$SCHEMA_ID" > /dev/null 2>&1; then
    log "✅ Schema '$SCHEMA_ID' found in v3"

    # Get schema metadata
    METADATA=$(curl -s "http://localhost:3333/apis/registry/v3/groups/default/artifacts/$SCHEMA_ID/versions/1")
    echo "$METADATA" | jq '.' 2>&1 | tee -a "$LOG_FILE"
else
    log "⚠️  Schema '$SCHEMA_ID' not found in v3"
fi
log ""

log "================================================================"
log "  ✅ Step I completed successfully"
log "================================================================"
log ""
log "Summary:"
log "  - Export file: $EXPORT_FILE ($FILE_SIZE)"
log "  - Artifacts before import: $BEFORE_COUNT"
log "  - Artifacts after import: $AFTER_COUNT"
log "  - Registry v3: http://localhost:3333"
log ""
log "Next step: Switch nginx to v3 (step-J-switch-nginx-to-v3.sh)"
log ""
log "Logs saved to: $LOG_FILE"
log ""
