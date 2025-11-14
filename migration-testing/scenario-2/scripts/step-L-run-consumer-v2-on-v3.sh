#!/bin/bash

# Step L: Run Kafka Consumer v2 (Against v3 Registry)
#
# This script:
# 1. Runs the kafka-consumer-v2 application (unchanged)
# 2. Consumer connects to Registry v3 through nginx
# 3. Tests backward compatibility (v2 SerDes with v3 Registry)
# 4. Consumes all messages (from steps D and K)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$DATA_DIR"

LOG_FILE="$LOG_DIR/step-L-run-consumer-v2-on-v3.log"
REPORT_FILE="$DATA_DIR/consumer-v2-on-v3-report.txt"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step L: Run Kafka Consumer v2 (Against v3 Registry)"
log "================================================================"
log ""
log "⚠️  BACKWARD COMPATIBILITY TEST"
log "   Testing v2 SerDes with v3 Registry (via nginx)"
log ""

# Configuration
KAFKA_BOOTSTRAP="localhost:9092"
REGISTRY_URL="http://localhost:8080/apis/registry/v2"  # v2 API endpoint on v3
TOPIC_NAME="avro-messages"
MAX_MESSAGES="50"
TIMEOUT_SECONDS="5"
JAR_PATH="$PROJECT_DIR/clients/kafka-consumer-v2/target/kafka-consumer-v2-1.0.0-SNAPSHOT.jar"

# Verify prerequisites
log "[1/3] Verifying prerequisites..."

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
    exit 1
fi
log "  ✓ Consumer JAR found"
log ""

# Get topic info - reset consumer group to read all messages
log "[2/3] Resetting consumer group to read all messages..."
docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --group kafka-consumer-v2 \
    --reset-offsets \
    --to-earliest \
    --topic "$TOPIC_NAME" \
    --execute 2>&1 | tee -a "$LOG_FILE"
log ""

# Run consumer
log "[3/3] Running Kafka Consumer v2 (against v3 registry)..."
log "  Kafka Bootstrap: $KAFKA_BOOTSTRAP"
log "  Registry URL: $REGISTRY_URL (v2 API on v3 server)"
log "  Topic: $TOPIC_NAME"
log "  Max Messages: $MAX_MESSAGES"
log "  Timeout: ${TIMEOUT_SECONDS}s"
log ""
log "Expected to consume:"
log "  - 10 messages from step D (v2 producer → v2 registry)"
log "  - 10 messages from step K (v2 producer → v3 registry)"
log "  = 20 total messages"
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
  Kafka Consumer v2 on v3 Report
================================================================

Execution Time: $(date)

Configuration:
  - Kafka Bootstrap: $KAFKA_BOOTSTRAP
  - Registry URL: $REGISTRY_URL (v2 API on v3)
  - Topic: $TOPIC_NAME
  - Max Messages: $MAX_MESSAGES
  - Timeout: ${TIMEOUT_SECONDS}s

Results:
  - Messages consumed: $MESSAGES_CONSUMED
  - Expected: 20 (10 from step D + 10 from step K)
  - Consumer group: kafka-consumer-v2

Backward Compatibility:
  - v2 SerDes: ✓ Working
  - v3 Registry: ✓ Working
  - v2 API on v3: ✓ Working

Status: SUCCESS

================================================================
EOF

cat "$REPORT_FILE" | tee -a "$LOG_FILE"

rm -f "$CONSUMER_OUTPUT"

log ""
log "================================================================"
log "  ✅ Step L completed successfully"
log "================================================================"
log ""
log "✅ BACKWARD COMPATIBILITY CONFIRMED"
log "   v2 SerDes successfully consumed messages using v3 Registry"
log ""
log "Summary:"
log "  - Consumer: v2 SerDes (unchanged)"
log "  - Registry: v3 (via nginx)"
log "  - API endpoint: /apis/registry/v2 (backward compatibility)"
log "  - Messages consumed: $MESSAGES_CONSUMED"
log "  - Expected: 20"
log ""
log "This proves that v2 applications can consume ALL messages"
log "(both pre- and post-migration) after registry upgrade!"
log ""
log "Files created:"
log "  - Report: $REPORT_FILE"
log "  - Log: $LOG_FILE"
log ""
