#!/bin/bash

# Step G: Run Kafka Consumer v2
#
# This script:
# 1. Runs the kafka-consumer-v2 application
# 2. Consumes messages from the 'avro-messages' topic
# 3. Verifies messages can be deserialized using the schema from Registry v2 (with TLS and Auth)
# 4. Saves consumption report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"
CERTS_DIR="$PROJECT_DIR/certs"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-G-run-consumer-v2.log"
REPORT_FILE="$DATA_DIR/consumer-v2-report.txt"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="https://localhost:8443/apis/registry/v2"
TOPIC_NAME="avro-messages"
MAX_MESSAGES="50"
TIMEOUT_SECONDS="5"
JAR_PATH="$PROJECT_DIR/clients/kafka-consumer-v2/target/kafka-consumer-v2-1.0.0-SNAPSHOT.jar"

# OAuth2 configuration
OAUTH_CLIENT_ID="registry-api"
OAUTH_CLIENT_SECRET="**********"
OAUTH_SERVER_URL="https://localhost:9443"
OAUTH_REALM="registry"
TRUSTSTORE_PATH="$CERTS_DIR/client-truststore.jks"
TRUSTSTORE_PASSWORD="registry123"

# Verify prerequisites
log "[1/3] Verifying prerequisites..."

# Check if Kafka is running
if ! docker exec scenario4-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    log "  Kafka is not running. Please run step-A-deploy-kafka.sh first."
    exit 1
fi
log "  Kafka is running"

# Check if Registry v2 is running (via nginx)
if ! curl -sf -k https://localhost:8443/health/live > /dev/null 2>&1; then
    log "  Registry v2 is not accessible. Please run step-C-deploy-v2.sh and step-D-deploy-nginx.sh first."
    exit 1
fi
log "  Registry v2 is accessible"

# Check if JAR exists
if [ ! -f "$JAR_PATH" ]; then
    log "  Consumer JAR not found: $JAR_PATH"
    log "   Please run: ./scripts/build-clients.sh"
    exit 1
fi
log "  Consumer JAR found"
log ""

# Get topic info
log "[2/3] Getting topic information..."
TOTAL_MESSAGES=$(docker exec scenario4-kafka /opt/kafka/bin/kafka-get-offsets.sh \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC_NAME" 2>/dev/null | awk -F: '{sum+=$3} END {print sum+0}')
log "  Total messages in topic: $TOTAL_MESSAGES"
log ""

# Run consumer
log "[3/3] Running Kafka Consumer v2..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL"
log "  Topic: $TOPIC_NAME"
log "  Max Messages: $MAX_MESSAGES"
log "  Timeout: ${TIMEOUT_SECONDS}s"
log "  OAuth2: enabled"
log "  TLS: enabled"
log ""

export KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP"
export REGISTRY_URL="$REGISTRY_URL"
export TOPIC_NAME="$TOPIC_NAME"
export MAX_MESSAGES="$MAX_MESSAGES"
export TIMEOUT_SECONDS="$TIMEOUT_SECONDS"
export OAUTH_CLIENT_ID="$OAUTH_CLIENT_ID"
export OAUTH_CLIENT_SECRET="$OAUTH_CLIENT_SECRET"
export OAUTH_SERVER_URL="$OAUTH_SERVER_URL"
export OAUTH_REALM="$OAUTH_REALM"
export TRUSTSTORE_PATH="$TRUSTSTORE_PATH"
export TRUSTSTORE_PASSWORD="$TRUSTSTORE_PASSWORD"

# Run consumer and save output
java -jar "$JAR_PATH" | tee -a "$LOG_FILE" > "$REPORT_FILE"
CONSUMER_EXIT_CODE=${PIPESTATUS[0]}

log ""
if [ $CONSUMER_EXIT_CODE -eq 0 ]; then
    log "  Consumer completed successfully"
elif [ $CONSUMER_EXIT_CODE -eq 124 ]; then
    log "  Consumer timed out after ${TIMEOUT_SECONDS}s (this is expected)"
else
    log "  Consumer failed with exit code $CONSUMER_EXIT_CODE"
    exit 1
fi
log ""

# Analyze results
log "Analyzing consumption results..."
MESSAGES_CONSUMED=$(grep -c "✓ \[Partition" "$REPORT_FILE" 2>/dev/null || true)
MESSAGES_CONSUMED=${MESSAGES_CONSUMED:-0}
log "  Messages consumed: $MESSAGES_CONSUMED"

if [ "$MESSAGES_CONSUMED" -gt 0 ]; then
    log "  Successfully consumed and deserialized $MESSAGES_CONSUMED messages"
else
    log "  No messages consumed (topic may be empty)"
fi
log ""

log "================================================================"
log "Summary:"
log "  - Messages in topic: $TOTAL_MESSAGES"
log "  - Messages consumed: $MESSAGES_CONSUMED"
log "  - Topic: $TOPIC_NAME"
log "  - Registry URL: $REGISTRY_URL"
log ""
log "Consumption report: $REPORT_FILE"
log ""
log "View topic messages:"
log "  docker exec scenario4-kafka /opt/kafka/bin/kafka-console-consumer.sh \\"
log "    --bootstrap-server localhost:9092 \\"
log "    --topic $TOPIC_NAME \\"
log "    --from-beginning \\"
log "    --max-messages $MAX_MESSAGES"
log ""
log "Logs saved to: $LOG_FILE"
log "================================================================"
