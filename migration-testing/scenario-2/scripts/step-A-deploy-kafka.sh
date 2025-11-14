#!/bin/bash

# Step A: Deploy Kafka Cluster
# This script deploys Apache Kafka 3.9.1 using KRaft mode (no Zookeeper)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose-kafka.yml"
LOG_DIR="$PROJECT_DIR/logs"
CONTAINER_LOG_DIR="$LOG_DIR/containers"

# Create log directories
mkdir -p "$LOG_DIR"
mkdir -p "$CONTAINER_LOG_DIR"

# Log file for this step
LOG_FILE="$LOG_DIR/step-A-deploy-kafka.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to wait for URL to be healthy
wait_for_url() {
    local url=$1
    local timeout=${2:-60}
    local interval=2
    local elapsed=0

    log "Waiting for $url to be healthy (timeout: ${timeout}s)..."
    while [ $elapsed -lt $timeout ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            log "✅ Health check passed after ${elapsed}s"
            return 0
        fi
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    log ""
    log "❌ Health check failed after ${timeout}s"
    return 1
}

# Function to wait for Kafka to be ready
wait_for_kafka() {
    local timeout=${1:-60}
    local interval=2
    local elapsed=0

    log "Waiting for Kafka broker to be ready (timeout: ${timeout}s)..."
    while [ $elapsed -lt $timeout ]; do
        if docker exec scenario2-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1; then
            log "✅ Kafka broker is ready after ${elapsed}s"
            return 0
        fi
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    log ""
    log "❌ Kafka broker failed to start after ${timeout}s"
    return 1
}

log "================================================================"
log "  Step A: Deploy Kafka Cluster"
log "================================================================"
log ""

# Step 1: Start Kafka
log "[1/5] Starting Kafka using KRaft mode (no Zookeeper)..."
docker compose -f "$COMPOSE_FILE" up -d
log ""

# Step 2: Wait for Kafka to be ready
log "[2/5] Waiting for Kafka broker to be ready..."
if ! wait_for_kafka 90; then
    log ""
    log "Failed to start Kafka. Check logs:"
    log "  docker logs scenario2-kafka"
    exit 1
fi
log ""

# Step 3: List brokers
log "[3/5] Verifying Kafka broker..."
docker exec scenario2-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 2>&1 | head -n 5 | tee -a "$LOG_FILE"
log ""

# Step 4: Create application topic
log "[4/5] Creating application topic 'avro-messages'..."
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create \
    --topic avro-messages \
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists 2>&1 | tee -a "$LOG_FILE"
log ""

# Step 5: Verify topic creation
log "[5/5] Verifying topics..."
docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --list 2>&1 | tee -a "$LOG_FILE"
log ""

# Collect container logs
log "Collecting Kafka logs..."
docker logs scenario2-kafka > "$CONTAINER_LOG_DIR/kafka-initial.log" 2>&1

log "================================================================"
log "  ✅ Step A completed successfully"
log "================================================================"
log ""
log "Kafka is running at: localhost:9092"
log ""
log "Topics created:"
log "  - avro-messages (3 partitions, replication factor 1)"
log ""
log "Useful commands:"
log "  List topics:"
log "    docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list"
log ""
log "  Describe topic:"
log "    docker exec scenario2-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic avro-messages"
log ""
log "  View logs:"
log "    docker logs scenario2-kafka"
log ""
log "Logs saved to:"
log "  - $LOG_FILE"
log "  - $CONTAINER_LOG_DIR/kafka-initial.log"
log ""
