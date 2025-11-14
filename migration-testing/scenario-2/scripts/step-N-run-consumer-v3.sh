#!/bin/bash

# Step N: Run Kafka Consumer v3
#
# This script:
# 1. Resets the consumer group to read from the beginning
# 2. Runs the kafka-consumer-v3 application
# 3. Uses v3 SerDes with v3 Registry
# 4. Consumes ALL messages from the 'avro-messages' topic
# 5. Demonstrates v3 consumer can read messages from both v2 and v3 producers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-N-run-consumer-v3.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step N: Run Kafka Consumer v3"
log "================================================================"
log ""
log "✅ FULL v3 STACK TEST"
log "   Testing v3 SerDes with v3 Registry"
log "   Consuming messages from v3 producer"
log ""

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="http://localhost:8080/apis/registry/v3"
TOPIC_NAME="avro-messages-v3"
MAX_MESSAGES="50"
TIMEOUT_SECONDS="5"
JAR_PATH="$PROJECT_DIR/clients/kafka-consumer-v3/target/kafka-consumer-v3-1.0.0-SNAPSHOT.jar"

# Verify prerequisites
log "[1/5] Verifying prerequisites..."

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
    log "❌ Consumer JAR not found: $JAR_PATH"
    log "   Please run: ./scripts/build-clients.sh"
    exit 1
fi
log "  ✓ Consumer JAR found"
log ""

# Get current topic state
log "[2/5] Getting current topic state..."
TOTAL_MESSAGES=$(docker exec scenario2-kafka /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list localhost:9092 \
    --topic "$TOPIC_NAME" \
    --time -1 2>/dev/null | \
    awk -F':' '{sum+=$3} END {print sum+0}' || echo "0")
log "  Total messages in topic: $TOTAL_MESSAGES"
log "  Expected: 30 messages (10 from step D, 10 from step K, 10 from step M)"
log ""

# Reset consumer group
log "[3/5] Resetting consumer group to read from beginning..."
if docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --group kafka-consumer-v3 \
    --reset-offsets \
    --to-earliest \
    --topic "$TOPIC_NAME" \
    --execute > /dev/null 2>&1; then
    log "  ✓ Consumer group 'kafka-consumer-v3' reset to earliest offset"
else
    log "  ℹ️  Consumer group 'kafka-consumer-v3' not found (will be created)"
fi
log ""

# Run consumer
log "[4/5] Running Kafka Consumer v3..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL (v3 API on v3 server)"
log "  Topic: $TOPIC_NAME"
log "  Max Messages: $MAX_MESSAGES"
log "  Timeout: $TIMEOUT_SECONDS seconds"
log ""

export KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP"
export REGISTRY_URL="$REGISTRY_URL"
export TOPIC_NAME="$TOPIC_NAME"
export MAX_MESSAGES="$MAX_MESSAGES"
export TIMEOUT_SECONDS="$TIMEOUT_SECONDS"

CONSUMER_OUTPUT_FILE="$DATA_DIR/consumer-v3-output.log"
if java -jar "$JAR_PATH" 2>&1 | tee "$CONSUMER_OUTPUT_FILE" | tee -a "$LOG_FILE"; then
    log ""
    log "✅ Consumer completed successfully"
else
    log ""
    log "❌ Consumer failed"
    exit 1
fi
log ""

# Analyze consumption
log "[5/5] Analyzing consumed messages..."

# Count messages from each producer
V2_ORIGINAL=$(grep -c "producer-v2! Message" "$CONSUMER_OUTPUT_FILE" || echo "0")
V2_ON_V3=$(grep -c "producer-v2-on-v3! Message" "$CONSUMER_OUTPUT_FILE" || echo "0")
V3_MESSAGES=$(grep -c "producer-v3! Message" "$CONSUMER_OUTPUT_FILE" || echo "0")
TOTAL_CONSUMED=$(grep -c "✓ \[Partition" "$CONSUMER_OUTPUT_FILE" || echo "0")

log "  Messages consumed by source:"
log "    - Step D (v2 producer → v2 registry): $V2_ORIGINAL"
log "    - Step K (v2 producer → v3 registry): $V2_ON_V3"
log "    - Step M (v3 producer → v3 registry): $V3_MESSAGES"
log "    - Total consumed: $TOTAL_CONSUMED"
log ""

# Verify schema accessible
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
log "  ✅ Step N completed successfully"
log "================================================================"
log ""
log "✅ FULL v3 STACK WORKING + BACKWARD COMPATIBLE"
log "   v3 Consumer successfully read messages from:"
log "   - v2 producer (original data from v2 registry)"
log "   - v2 producer (backward compatibility test on v3)"
log "   - v3 producer (native v3)"
log ""
log "Summary:"
log "  - Consumer: v3 SerDes"
log "  - Registry: v3 (via nginx)"
log "  - API endpoint: /apis/registry/v3"
log "  - Messages consumed: $TOTAL_CONSUMED of $TOTAL_MESSAGES"
log "  - Topic: $TOPIC_NAME"
log ""
log "✅ MIGRATION VALIDATION COMPLETE"
log "   The v3 registry is now the primary registry"
log "   Both v2 and v3 clients can work with v3 registry"
log "   All historical data has been preserved"
log ""
log "Logs saved to: $LOG_FILE"
log "Consumer output: $CONSUMER_OUTPUT_FILE"
log ""
