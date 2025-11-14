#!/bin/bash

# Step D: Run Kafka Producer v2
#
# This script:
# 1. Runs the kafka-producer-v2 application
# 2. Produces messages to the 'avro-messages' topic
# 3. Auto-registers the Avro schema in Registry v2
# 4. Verifies the schema was registered

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-D-run-producer-v2.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step D: Run Kafka Producer v2"
log "================================================================"
log ""

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="http://localhost:8080/apis/registry/v2"
TOPIC_NAME="avro-messages"
MESSAGE_COUNT="10"
JAR_PATH="$PROJECT_DIR/clients/kafka-producer-v2/target/kafka-producer-v2-1.0.0-SNAPSHOT.jar"

# Verify prerequisites
log "[1/4] Verifying prerequisites..."

# Check if Kafka is running
if ! docker exec scenario2-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    log "❌ Kafka is not running. Please run step-A-deploy-kafka.sh first."
    exit 1
fi
log "  ✓ Kafka is running"

# Check if Registry v2 is running
if ! curl -sf http://localhost:8080/health/live > /dev/null 2>&1; then
    log "❌ Registry is not accessible. Please run step-B-deploy-v2-kafka.sh and step-C-deploy-nginx.sh first."
    exit 1
fi
log "  ✓ Registry is accessible"

# Check if JAR exists
if [ ! -f "$JAR_PATH" ]; then
    log "❌ Producer JAR not found: $JAR_PATH"
    log "   Please run: ./scripts/build-clients.sh"
    exit 1
fi
log "  ✓ Producer JAR found"
log ""

# Get message count before producing
log "[2/4] Getting current topic offset..."
OFFSET_BEFORE=$(docker exec scenario2-kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list localhost:9092 \
    --topic "$TOPIC_NAME" 2>/dev/null | awk -F: '{sum+=$3} END {print sum+0}')
log "  Current offset: $OFFSET_BEFORE"
log ""

# Run producer
log "[3/4] Running Kafka Producer v2..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL"
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
log "[4/4] Verifying messages were produced..."
sleep 2
OFFSET_AFTER=$(docker exec scenario2-kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list localhost:9092 \
    --topic "$TOPIC_NAME" 2>/dev/null | awk -F: '{sum+=$3} END {print sum+0}')
log "  Offset after: $OFFSET_AFTER"

MESSAGES_PRODUCED=$((OFFSET_AFTER - OFFSET_BEFORE))
log "  Messages produced: $MESSAGES_PRODUCED"

if [ "$MESSAGES_PRODUCED" -ge "$MESSAGE_COUNT" ]; then
    log "✅ Verified $MESSAGES_PRODUCED messages in topic"
else
    log "⚠️  Expected $MESSAGE_COUNT messages, found $MESSAGES_PRODUCED"
fi
log ""

# Check if schema was registered
log "Checking for registered schemas..."
SCHEMAS=$(curl -s http://localhost:8080/apis/registry/v2/search/artifacts?group=default | jq -r '.artifacts[].artifactId' 2>/dev/null || echo "")
if [ -n "$SCHEMAS" ]; then
    log "✅ Schemas registered:"
    echo "$SCHEMAS" | while read -r schema; do
        log "  - $schema"
    done
else
    log "⚠️  No schemas found in registry"
fi
log ""

log "================================================================"
log "  ✅ Step D completed successfully"
log "================================================================"
log ""
log "Summary:"
log "  - Messages produced: $MESSAGES_PRODUCED"
log "  - Topic: $TOPIC_NAME"
log "  - Registry URL: $REGISTRY_URL"
log ""
log "View topic messages:"
log "  docker exec scenario2-kafka /opt/kafka/bin/kafka-console-consumer.sh \\"
log "    --bootstrap-server localhost:9092 \\"
log "    --topic $TOPIC_NAME \\"
log "    --from-beginning \\"
log "    --max-messages $MESSAGE_COUNT"
log ""
log "View registered schemas:"
log "  curl http://localhost:8080/apis/registry/v2/search/artifacts?group=default | jq"
log ""
log "Logs saved to: $LOG_FILE"
log ""
