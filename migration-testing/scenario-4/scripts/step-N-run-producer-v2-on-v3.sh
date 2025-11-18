#!/bin/bash

# Step N: Run Kafka Producer v2 on Registry v3
#
# This script:
# 1. Runs the kafka-producer-v2 application against Registry v3
# 2. Produces messages to the 'avro-messages' topic
# 3. Tests v2 SerDes backward compatibility with Registry v3 (with TLS and Auth)
# 4. Verifies the schema was registered

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"
CERTS_DIR="$PROJECT_DIR/certs"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-N-run-producer-v2-on-v3.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="https://localhost:8443/apis/registry/v2"
TOPIC_NAME="avro-messages"
MESSAGE_COUNT="10"
JAR_PATH="$PROJECT_DIR/clients/kafka-producer-v2/target/kafka-producer-v2-1.0.0-SNAPSHOT.jar"

# OAuth2 configuration
OAUTH_CLIENT_ID="registry-api"
OAUTH_CLIENT_SECRET="**********"
OAUTH_SERVER_URL="https://localhost:9443"
OAUTH_REALM="registry"
TRUSTSTORE_PATH="$CERTS_DIR/client-truststore.jks"
TRUSTSTORE_PASSWORD="registry123"

# Verify prerequisites
log "[1/4] Verifying prerequisites..."

# Check if Kafka is running
if ! docker exec scenario4-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    log "  Kafka is not running. Please run step-M-deploy-kafka.sh first."
    exit 1
fi
log "  Kafka is running"

# Check if Registry v3 is running (via nginx)
if ! curl -sf -k https://localhost:8443/health/live > /dev/null 2>&1; then
    log "  Registry v3 is not accessible. Please run step-K-deploy-v3.sh, step-L-import-v3-data.sh, and step-M-switch-nginx-to-v3.sh first."
    exit 1
fi
log "  Registry v3 is accessible"

# Check if JAR exists
if [ ! -f "$JAR_PATH" ]; then
    log "  Producer JAR not found: $JAR_PATH"
    log "   Please run: ./scripts/build-clients.sh"
    exit 1
fi
log "  Producer JAR found"
log ""

# Get message count before producing
log "[2/4] Getting current topic offset..."
OFFSET_BEFORE=$(docker exec scenario4-kafka /opt/kafka/bin/kafka-get-offsets.sh \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC_NAME" 2>/dev/null | awk -F: '{sum+=$3} END {print sum+0}')
log "  Current offset: $OFFSET_BEFORE"
log ""

# Run producer
log "[3/4] Running Kafka Producer v2..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL"
log "  Topic: $TOPIC_NAME"
log "  Message Count: $MESSAGE_COUNT"
log "  OAuth2: enabled"
log "  TLS: enabled"
log ""

export KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP"
export REGISTRY_URL="$REGISTRY_URL"
export TOPIC_NAME="$TOPIC_NAME"
export MESSAGE_COUNT="$MESSAGE_COUNT"
export OAUTH_CLIENT_ID="$OAUTH_CLIENT_ID"
export OAUTH_CLIENT_SECRET="$OAUTH_CLIENT_SECRET"
export OAUTH_SERVER_URL="$OAUTH_SERVER_URL"
export OAUTH_REALM="$OAUTH_REALM"
export TRUSTSTORE_PATH="$TRUSTSTORE_PATH"
export TRUSTSTORE_PASSWORD="$TRUSTSTORE_PASSWORD"

# Run producer and capture exit code properly
java -jar "$JAR_PATH" 2>&1 | tee -a "$LOG_FILE"
PRODUCER_EXIT_CODE=${PIPESTATUS[0]}

log ""
if [ $PRODUCER_EXIT_CODE -eq 0 ]; then
    log "  Producer completed successfully"
else
    log "  Producer failed with exit code $PRODUCER_EXIT_CODE"
    exit 1
fi
log ""

# Verify messages were produced
log "[4/4] Verifying messages were produced..."
sleep 2
OFFSET_AFTER=$(docker exec scenario4-kafka /opt/kafka/bin/kafka-get-offsets.sh \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC_NAME" 2>/dev/null | awk -F: '{sum+=$3} END {print sum+0}')
log "  Offset after: $OFFSET_AFTER"

MESSAGES_PRODUCED=$((OFFSET_AFTER - OFFSET_BEFORE))
log "  Messages produced: $MESSAGES_PRODUCED"

if [ "$MESSAGES_PRODUCED" -ge "$MESSAGE_COUNT" ]; then
    log "  Verified $MESSAGES_PRODUCED messages in topic"
else
    log "  Expected $MESSAGE_COUNT messages, found $MESSAGES_PRODUCED"
fi
log ""

# Check if schema was registered in v3
log "Checking for registered schemas in Registry v3..."
SCHEMAS=$(curl -s -k https://localhost:8443/apis/registry/v2/search/artifacts?group=default | jq -r '.artifacts[].artifactId' 2>/dev/null || echo "")
if [ -n "$SCHEMAS" ]; then
    log "  Schemas registered:"
    echo "$SCHEMAS" | while read -r schema; do
        log "  - $schema"
    done
else
    log "  No schemas found in registry"
fi
log ""

log "================================================================"
log "Summary:"
log "  - Messages produced: $MESSAGES_PRODUCED"
log "  - Topic: $TOPIC_NAME"
log "  - Registry URL: $REGISTRY_URL"
log ""
log "View topic messages:"
log "  docker exec scenario4-kafka /opt/kafka/bin/kafka-console-consumer.sh \\"
log "    --bootstrap-server localhost:9092 \\"
log "    --topic $TOPIC_NAME \\"
log "    --from-beginning \\"
log "    --max-messages $MESSAGE_COUNT"
log ""
log "View registered schemas:"
log "  curl -k https://localhost:8443/apis/registry/v2/search/artifacts?group=default | jq"
log ""
log "Logs saved to: $LOG_FILE"
log "================================================================"
