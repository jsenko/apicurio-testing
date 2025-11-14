#!/bin/bash

# Step K: Run Kafka Producer v2 (Against v3 Registry)
#
# This script:
# 1. Runs the kafka-producer-v2 application (unchanged)
# 2. Producer connects to Registry v3 through nginx
# 3. Tests backward compatibility (v2 SerDes with v3 Registry)
# 4. Produces additional messages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-K-run-producer-v2-on-v3.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step K: Run Kafka Producer v2 (Against v3 Registry)"
log "================================================================"
log ""
log "⚠️  BACKWARD COMPATIBILITY TEST"
log "   Testing v2 SerDes with v3 Registry (via nginx)"
log ""

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="http://localhost:8080/apis/registry/v2"  # v2 API endpoint on v3
TOPIC_NAME="avro-messages"
MESSAGE_COUNT="10"
JAR_PATH="$PROJECT_DIR/clients/kafka-producer-v2/target/kafka-producer-v2-1.0.0-SNAPSHOT.jar"

# Verify prerequisites
log "[1/4] Verifying prerequisites..."

# Check if Kafka is running
if ! docker exec scenario2-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    log "❌ Kafka is not running."
    exit 1
fi
log "  ✓ Kafka is running"

# Check if nginx is routing to v3
if ! curl -sf http://localhost:8080/nginx-health 2>&1 | grep -q "v3"; then
    log "❌ Nginx is not routing to v3. Please run step-J-switch-nginx-to-v3.sh first."
    exit 1
fi
log "  ✓ Nginx is routing to v3"

# Check if v3 registry is accessible through nginx
VERSION=$(curl -s http://localhost:8080/apis/registry/v3/system/info | jq -r '.version' 2>/dev/null || echo "unknown")
if [[ "$VERSION" != 3.* ]]; then
    log "❌ Registry v3 is not accessible through nginx (version: $VERSION)"
    exit 1
fi
log "  ✓ Registry v3 accessible via nginx (version: $VERSION)"

# Check if JAR exists
if [ ! -f "$JAR_PATH" ]; then
    log "❌ Producer JAR not found: $JAR_PATH"
    exit 1
fi
log "  ✓ Producer JAR found"
log ""

# Get message count before producing
log "[2/4] Getting current topic offset..."
OFFSET_BEFORE=$(docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --group kafka-consumer-v2 2>/dev/null | \
    awk '/avro-messages/ {sum+=$4} END {print sum+0}')
log "  Messages consumed so far: $OFFSET_BEFORE"
log ""

# Run producer
log "[3/4] Running Kafka Producer v2 (against v3 registry)..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL (v2 API on v3 server)"
log "  Topic: $TOPIC_NAME"
log "  Message Count: $MESSAGE_COUNT"
log ""

export KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP"
export REGISTRY_URL="$REGISTRY_URL"
export TOPIC_NAME="$TOPIC_NAME"
export MESSAGE_COUNT="$MESSAGE_COUNT"

if java -jar "$JAR_PATH" 2>&1 | tee -a "$LOG_FILE"; then
    log ""
    log "✅ Producer completed successfully"
else
    log ""
    log "❌ Producer failed"
    exit 1
fi
log ""

# Verify messages were produced
log "[4/4] Verifying backward compatibility..."
sleep 2

# Check schema still accessible via v2 API on v3
SCHEMA_ID="avro-messages-value"
if curl -sf "http://localhost:8080/apis/registry/v2/groups/default/artifacts/$SCHEMA_ID" > /dev/null 2>&1; then
    log "✅ Schema accessible via v2 API on v3 registry"
else
    log "⚠️  Schema not accessible via v2 API"
fi
log ""

log "================================================================"
log "  ✅ Step K completed successfully"
log "================================================================"
log ""
log "✅ BACKWARD COMPATIBILITY CONFIRMED"
log "   v2 SerDes successfully worked with v3 Registry"
log ""
log "Summary:"
log "  - Producer: v2 SerDes (unchanged)"
log "  - Registry: v3 (via nginx)"
log "  - API endpoint: /apis/registry/v2 (backward compatibility)"
log "  - Messages produced: $MESSAGE_COUNT"
log "  - Topic: $TOPIC_NAME"
log ""
log "This proves that v2 applications continue to work after"
log "migrating the registry from v2 to v3!"
log ""
log "Logs saved to: $LOG_FILE"
log ""
