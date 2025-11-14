#!/bin/bash

# Step E: Run Kafka Consumer v2
#
# This script:
# 1. Runs the kafka-consumer-v2 application
# 2. Consumes messages from the 'avro-messages' topic
# 3. Verifies messages can be deserialized using the schema from Registry v2
# 4. Saves consumption report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-E-run-consumer-v2.log"
REPORT_FILE="$DATA_DIR/consumer-v2-report.txt"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step E: Run Kafka Consumer v2"
log "================================================================"
log ""

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="http://localhost:8080/apis/registry/v2"
TOPIC_NAME="avro-messages"
MAX_MESSAGES="50"
TIMEOUT_SECONDS="5"
JAR_PATH="$PROJECT_DIR/clients/kafka-consumer-v2/target/kafka-consumer-v2-1.0.0-SNAPSHOT.jar"

# Verify prerequisites
log "[1/3] Verifying prerequisites..."

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
    log "❌ Consumer JAR not found: $JAR_PATH"
    log "   Please run: ./scripts/build-clients.sh"
    exit 1
fi
log "  ✓ Consumer JAR found"
log ""

# Get topic info
log "[2/3] Getting topic information..."
TOTAL_MESSAGES=$(docker exec scenario2-kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list localhost:9092 \
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
log ""

export KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP"
export REGISTRY_URL="$REGISTRY_URL"
export TOPIC_NAME="$TOPIC_NAME"
export MAX_MESSAGES="$MAX_MESSAGES"
export TIMEOUT_SECONDS="$TIMEOUT_SECONDS"

# Capture consumer output
CONSUMER_OUTPUT=$(mktemp)
if java -jar "$JAR_PATH" 2>&1 | tee "$CONSUMER_OUTPUT" | tee -a "$LOG_FILE"; then
    log ""
    log "✅ Consumer completed successfully"
else
    log ""
    log "❌ Consumer failed"
    rm -f "$CONSUMER_OUTPUT"
    exit 1
fi
log ""

# Extract consumption statistics
MESSAGES_CONSUMED=$(grep -c "✓ \[Partition" "$CONSUMER_OUTPUT" || echo "0")

# Save report
log "Saving consumption report..."
cat > "$REPORT_FILE" <<EOF
================================================================
  Kafka Consumer v2 Report
================================================================

Execution Time: $(date)

Configuration:
  - Kafka Bootstrap: $KAFKA_BOOTSTRAP
  - Registry URL: $REGISTRY_URL
  - Topic: $TOPIC_NAME
  - Max Messages: $MAX_MESSAGES
  - Timeout: ${TIMEOUT_SECONDS}s

Results:
  - Messages available in topic: $TOTAL_MESSAGES
  - Messages consumed: $MESSAGES_CONSUMED
  - Consumer group: kafka-consumer-v2

Status: SUCCESS

================================================================
EOF

cat "$REPORT_FILE" | tee -a "$LOG_FILE"

rm -f "$CONSUMER_OUTPUT"

log ""
log "================================================================"
log "  ✅ Step E completed successfully"
log "================================================================"
log ""
log "Summary:"
log "  - Messages consumed: $MESSAGES_CONSUMED"
log "  - Topic: $TOPIC_NAME"
log "  - Registry URL: $REGISTRY_URL"
log ""
log "Consumer group status:"
docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --group kafka-consumer-v2 2>&1 | tee -a "$LOG_FILE"
log ""
log "Files created:"
log "  - Report: $REPORT_FILE"
log "  - Log: $LOG_FILE"
log ""
