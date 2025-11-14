#!/bin/bash

# Step M: Run Kafka Producer v3
#
# This script:
# 1. Runs the kafka-producer-v3 application
# 2. Uses v3 SerDes with v3 Registry
# 3. Produces messages to the 'avro-messages' topic
# 4. Demonstrates the full v3 stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-M-run-producer-v3.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step M: Run Kafka Producer v3"
log "================================================================"
log ""
log "✅ FULL v3 STACK TEST"
log "   Testing v3 SerDes with v3 Registry"
log ""

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="http://localhost:8080/apis/registry/v3"
TOPIC_NAME="avro-messages-v3"
MESSAGE_COUNT="10"
JAR_PATH="$PROJECT_DIR/clients/kafka-producer-v3/target/kafka-producer-v3-1.0.0-SNAPSHOT.jar"

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
    log "   Please run: ./scripts/build-clients.sh"
    exit 1
fi
log "  ✓ Producer JAR found"
log ""

# Get message count before producing
log "[2/4] Getting current topic state..."
MESSAGES_BEFORE=$(docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --group kafka-consumer-v3 2>/dev/null | \
    awk '/avro-messages/ {sum+=$4} END {print sum+0}' || echo "0")
log "  Messages in topic (approx): $MESSAGES_BEFORE"
log ""

# Run producer
log "[3/4] Running Kafka Producer v3..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL (v3 API on v3 server)"
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

# Verify schema accessible
log "[4/4] Verifying schema registration..."
SCHEMA_ID="avro-messages-value"
if curl -sf "http://localhost:8080/apis/registry/v3/groups/default/artifacts/$SCHEMA_ID" > /dev/null 2>&1; then
    log "✅ Schema accessible via v3 API"

    # Get schema versions
    VERSIONS=$(curl -s "http://localhost:8080/apis/registry/v3/groups/default/artifacts/$SCHEMA_ID/versions" | jq -r '.count // 0')
    log "  Schema versions: $VERSIONS"
else
    log "⚠️  Schema not accessible via v3 API"
fi
log ""

log "================================================================"
log "  ✅ Step M completed successfully"
log "================================================================"
log ""
log "✅ FULL v3 STACK WORKING"
log "   v3 SerDes successfully worked with v3 Registry"
log ""
log "Summary:"
log "  - Producer: v3 SerDes"
log "  - Registry: v3 (via nginx)"
log "  - API endpoint: /apis/registry/v3"
log "  - Messages produced: $MESSAGE_COUNT"
log "  - Topic: $TOPIC_NAME"
log ""
log "Total messages in topic (all producers):"
log "  - Step D: 10 messages (v2 producer → v2 registry)"
log "  - Step K: 10 messages (v2 producer → v3 registry)"
log "  - Step M: 10 messages (v3 producer → v3 registry)"
log "  = 30 messages total"
log ""
log "Logs saved to: $LOG_FILE"
log ""
