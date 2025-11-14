#!/bin/bash

# Build all Kafka client applications
# This script builds both v2 and v3 producer and consumer applications

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="$PROJECT_DIR/clients"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
LOG_FILE="$PROJECT_DIR/logs/build-clients.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Building Kafka Client Applications" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Function to build a client
build_client() {
    local client_name=$1
    local client_dir="$CLIENTS_DIR/$client_name"

    if [ ! -d "$client_dir" ]; then
        echo "⚠️  Skipping $client_name (not found)" | tee -a "$LOG_FILE"
        return 0
    fi

    echo "Building $client_name..." | tee -a "$LOG_FILE"
    cd "$client_dir"

    if mvn clean package -DskipTests 2>&1 | tee -a "$LOG_FILE"; then
        echo "✅ $client_name built successfully" | tee -a "$LOG_FILE"

        # Find and display the JAR location
        JAR_FILE=$(find target -name "*-SNAPSHOT.jar" -not -name "*-original-*" | head -n 1)
        if [ -n "$JAR_FILE" ]; then
            echo "   JAR: $client_dir/$JAR_FILE" | tee -a "$LOG_FILE"
        fi
        echo "" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Failed to build $client_name" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Build all clients
CLIENTS=(
    "kafka-producer-v2"
    "kafka-consumer-v2"
    "kafka-producer-v3"
    "kafka-consumer-v3"
)

FAILED_BUILDS=()

for client in "${CLIENTS[@]}"; do
    if ! build_client "$client"; then
        FAILED_BUILDS+=("$client")
    fi
done

cd "$PROJECT_DIR"

echo "================================================================" | tee -a "$LOG_FILE"
if [ ${#FAILED_BUILDS[@]} -eq 0 ]; then
    echo "  ✅ All client applications built successfully" | tee -a "$LOG_FILE"
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Logs saved to: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
else
    echo "  ❌ Build failed for:" | tee -a "$LOG_FILE"
    for client in "${FAILED_BUILDS[@]}"; do
        echo "     - $client" | tee -a "$LOG_FILE"
    done
    echo "================================================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Logs saved to: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi
