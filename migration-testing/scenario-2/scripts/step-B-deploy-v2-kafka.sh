#!/bin/bash

# Step B: Deploy Apicurio Registry 2.6.x with KafkaSQL
#
# This script:
# 1. Deploys Apicurio Registry 2.6.13.Final with KafkaSQL storage
# 2. Waits for health checks to pass
# 3. Verifies system info
# 4. Verifies kafkasql-journal-v2 topic created

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-B-deploy-v2-kafka.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step B: Deploy Apicurio Registry 2.6.13 with KafkaSQL"
log "================================================================"
log ""

# Navigate to project directory
cd "$PROJECT_DIR"

log "[1/5] Verifying Kafka is running..."
if ! docker exec scenario2-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    log "❌ Kafka is not running. Please run step-A-deploy-kafka.sh first."
    exit 1
fi
log "✅ Kafka is running"
log ""

log "[2/5] Starting Registry v2 with KafkaSQL storage..."
docker compose -f docker-compose-v2-kafka.yml up -d 2>&1 | tee -a "$LOG_FILE"
log ""

log "[3/5] Waiting for Registry v2 to be healthy..."
"$SCRIPT_DIR/wait-for-health.sh" http://localhost:2222/health/live 120 2>&1 | tee -a "$LOG_FILE"
log ""

log "[4/5] Verifying system info..."
SYSTEM_INFO=$(curl -s http://localhost:2222/apis/registry/v2/system/info)
echo "$SYSTEM_INFO" | jq '.' 2>&1 | tee -a "$LOG_FILE"

VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version')
log ""
log "Registry Version: $VERSION"

# Validate version is 2.6.x
if [[ "$VERSION" != 2.6.* ]]; then
    log "❌ Expected version 2.6.x but got $VERSION"
    exit 1
fi
log ""

log "[5/5] Verifying KafkaSQL topic created..."
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --list 2>&1 | tee -a "$LOG_FILE"

# Check if kafkasql-journal-v2 topic exists
if docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>&1 | grep -q "kafkasql-journal-v2"; then
    log "✅ Topic 'kafkasql-journal-v2' created successfully"
else
    log "❌ Topic 'kafkasql-journal-v2' not found"
    exit 1
fi
log ""

log "Topic details:"
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --topic kafkasql-journal-v2 2>&1 | tee -a "$LOG_FILE"
log ""

log "Consumer groups:"
docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --list 2>&1 | tee -a "$LOG_FILE"
log ""

log "================================================================"
log "  ✅ Step B completed successfully"
log "================================================================"
log ""
log "Registry v2 is running at: http://localhost:2222"
log "Storage: KafkaSQL (Kafka topic: kafkasql-journal-v2)"
log ""
log "Test endpoints:"
log "  curl http://localhost:2222/apis/registry/v2/system/info"
log "  curl http://localhost:2222/health/live"
log ""
log "Container logs:"
log "  docker logs scenario2-registry-v2"
log ""

# Collect initial container logs
log "Collecting initial container logs..."
docker logs scenario2-registry-v2 > "$PROJECT_DIR/logs/containers/registry-v2-initial.log" 2>&1

log "Logs saved to:"
log "  - $LOG_FILE"
log "  - $PROJECT_DIR/logs/containers/registry-v2-initial.log"
log ""
