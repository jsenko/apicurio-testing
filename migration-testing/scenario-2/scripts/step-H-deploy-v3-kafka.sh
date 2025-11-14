#!/bin/bash

# Step H: Deploy Apicurio Registry 3.1.x with KafkaSQL
#
# This script:
# 1. Deploys Apicurio Registry 3.1.2 with KafkaSQL storage
# 2. Uses a SEPARATE Kafka topic (kafkasql-journal-v3) from v2
# 3. Waits for health checks to pass
# 4. Verifies system info

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-H-deploy-v3-kafka.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step H: Deploy Apicurio Registry 3.1.2 with KafkaSQL"
log "================================================================"
log ""

# Navigate to project directory
cd "$PROJECT_DIR"

log "[1/6] Verifying Kafka is running..."
if ! docker exec scenario2-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    log "❌ Kafka is not running. Please run step-A-deploy-kafka.sh first."
    exit 1
fi
log "✅ Kafka is running"
log ""

log "[2/6] Creating v3 network if needed..."
if ! docker network inspect scenario2-v3-network > /dev/null 2>&1; then
    docker network create scenario2-v3-network 2>&1 | tee -a "$LOG_FILE"
    log "✅ Network 'scenario2-v3-network' created"
else
    log "ℹ️  Network 'scenario2-v3-network' already exists"
fi
log ""

log "[3/6] Starting Registry v3 with KafkaSQL storage..."
log "⚠️  IMPORTANT: v3 uses a SEPARATE Kafka topic (kafkasql-journal-v3)"
log "   v3 CANNOT read v2's journal - migration requires export/import"
log ""
docker compose -f docker-compose-v3-kafka.yml up -d 2>&1 | tee -a "$LOG_FILE"
log ""

log "[4/6] Waiting for Registry v3 to be healthy..."
"$SCRIPT_DIR/wait-for-health.sh" http://localhost:3333/health/live 240 2>&1 | tee -a "$LOG_FILE"
log ""

log "[5/6] Verifying system info..."
SYSTEM_INFO=$(curl -s http://localhost:3333/apis/registry/v3/system/info)
echo "$SYSTEM_INFO" | jq '.' 2>&1 | tee -a "$LOG_FILE"

VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version')
log ""
log "Registry Version: $VERSION"

# Validate version is 3.x
if [[ "$VERSION" != 3.* ]]; then
    log "❌ Expected version 3.x but got $VERSION"
    exit 1
fi
log ""

log "[6/6] Verifying KafkaSQL topic created..."
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --list 2>&1 | tee -a "$LOG_FILE"

# Check if kafkasql-journal-v3 topic exists
if docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list 2>&1 | grep -q "kafkasql-journal-v3"; then
    log "✅ Topic 'kafkasql-journal-v3' created successfully"
else
    log "❌ Topic 'kafkasql-journal-v3' not found"
    exit 1
fi
log ""

log "Topic details:"
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --topic kafkasql-journal-v3 2>&1 | tee -a "$LOG_FILE"
log ""

log "All Kafka topics:"
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --list 2>&1 | tee -a "$LOG_FILE"
log ""

log "Consumer groups:"
docker exec scenario2-kafka /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --list 2>&1 | tee -a "$LOG_FILE"
log ""

log "================================================================"
log "  ✅ Step H completed successfully"
log "================================================================"
log ""
log "Registry v3 is running at: http://localhost:3333"
log "Storage: KafkaSQL (Kafka topic: kafkasql-journal-v3)"
log ""
log "⚠️  IMPORTANT: Registry v3 is currently EMPTY"
log "   v2 topic: kafkasql-journal-v2"
log "   v3 topic: kafkasql-journal-v3"
log "   Data must be imported from v2 export (step-I-import-v3-data.sh)"
log ""
log "Test endpoints:"
log "  curl http://localhost:3333/apis/registry/v3/system/info"
log "  curl http://localhost:3333/health/live"
log ""
log "Container logs:"
log "  docker logs scenario2-registry-v3"
log ""

# Collect initial container logs
log "Collecting initial container logs..."
docker logs scenario2-registry-v3 > "$PROJECT_DIR/logs/containers/registry-v3-initial.log" 2>&1

log "Logs saved to:"
log "  - $LOG_FILE"
log "  - $PROJECT_DIR/logs/containers/registry-v3-initial.log"
log ""
