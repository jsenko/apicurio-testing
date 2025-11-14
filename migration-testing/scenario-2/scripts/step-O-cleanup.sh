#!/bin/bash

# Step O: Cleanup
#
# This script:
# 1. Stops all running containers
# 2. Removes containers and networks
# 3. Optionally removes volumes and data directories
# 4. Cleans up the test environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
DATA_DIR="$PROJECT_DIR/data"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/step-O-cleanup.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step O: Cleanup"
log "================================================================"
log ""

# Parse arguments
REMOVE_VOLUMES=false
REMOVE_DATA=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        --remove-data)
            REMOVE_DATA=true
            shift
            ;;
        *)
            log "Unknown option: $1"
            log "Usage: $0 [--remove-volumes] [--remove-data]"
            log "  --remove-volumes: Remove Docker volumes (Kafka data, Registry data)"
            log "  --remove-data: Remove logs and data directories"
            exit 1
            ;;
    esac
done

log "Cleanup options:"
log "  Remove volumes: $REMOVE_VOLUMES"
log "  Remove data: $REMOVE_DATA"
log ""

# Stop nginx
log "[1/7] Stopping nginx..."
cd "$PROJECT_DIR"
if docker compose -f docker-compose-nginx.yml ps -q nginx > /dev/null 2>&1; then
    docker compose -f docker-compose-nginx.yml down
    log "  ✓ Nginx stopped"
else
    log "  ℹ️  Nginx not running"
fi
log ""

# Stop Registry v3
log "[2/7] Stopping Registry v3..."
if docker compose -f docker-compose-v3-kafka.yml ps -q registry-v3 > /dev/null 2>&1; then
    if [ "$REMOVE_VOLUMES" = true ]; then
        docker compose -f docker-compose-v3-kafka.yml down -v
        log "  ✓ Registry v3 stopped (volumes removed)"
    else
        docker compose -f docker-compose-v3-kafka.yml down
        log "  ✓ Registry v3 stopped (volumes retained)"
    fi
else
    log "  ℹ️  Registry v3 not running"
fi
log ""

# Stop Registry v2
log "[3/7] Stopping Registry v2..."
if docker compose -f docker-compose-v2-kafka.yml ps -q registry-v2 > /dev/null 2>&1; then
    if [ "$REMOVE_VOLUMES" = true ]; then
        docker compose -f docker-compose-v2-kafka.yml down -v
        log "  ✓ Registry v2 stopped (volumes removed)"
    else
        docker compose -f docker-compose-v2-kafka.yml down
        log "  ✓ Registry v2 stopped (volumes retained)"
    fi
else
    log "  ℹ️  Registry v2 not running"
fi
log ""

# Stop Kafka
log "[4/7] Stopping Kafka..."
if docker compose -f docker-compose-kafka.yml ps -q kafka > /dev/null 2>&1; then
    if [ "$REMOVE_VOLUMES" = true ]; then
        docker compose -f docker-compose-kafka.yml down -v
        log "  ✓ Kafka stopped (volumes removed)"
    else
        docker compose -f docker-compose-kafka.yml down
        log "  ✓ Kafka stopped (volumes retained)"
    fi
else
    log "  ℹ️  Kafka not running"
fi
log ""

# Clean up networks
log "[5/7] Cleaning up networks..."
NETWORKS_REMOVED=0
for network in scenario2-kafka-network scenario2-v2-network scenario2-v3-network; do
    if docker network ls | grep -q "$network"; then
        if docker network rm "$network" 2>/dev/null; then
            log "  ✓ Network '$network' removed"
            NETWORKS_REMOVED=$((NETWORKS_REMOVED + 1))
        else
            log "  ⚠️  Failed to remove network '$network' (may have active endpoints)"
        fi
    fi
done
if [ $NETWORKS_REMOVED -eq 0 ]; then
    log "  ℹ️  No networks to remove"
fi
log ""

# Remove data directory
if [ "$REMOVE_DATA" = true ]; then
    log "[6/7] Removing data directory..."
    if [ -d "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
        log "  ✓ Data directory removed: $DATA_DIR"
    else
        log "  ℹ️  Data directory not found"
    fi
    log ""

    log "[7/7] Removing logs directory..."
    # Keep the current log file, remove others
    if [ -d "$LOG_DIR" ]; then
        find "$LOG_DIR" -type f ! -name "step-O-cleanup.log" -delete
        log "  ✓ Log files removed (except cleanup log)"
    else
        log "  ℹ️  Log directory not found"
    fi
    log ""
else
    log "[6/7] Keeping data directory..."
    log "  ℹ️  Data directory retained: $DATA_DIR"
    log ""

    log "[7/7] Keeping logs directory..."
    log "  ℹ️  Logs directory retained: $LOG_DIR"
    log ""
fi

log "================================================================"
log "  ✅ Step O completed successfully"
log "================================================================"
log ""
log "Cleanup summary:"
log "  - All containers stopped"
log "  - Networks removed"
if [ "$REMOVE_VOLUMES" = true ]; then
    log "  - Docker volumes removed"
else
    log "  - Docker volumes retained (use --remove-volumes to remove)"
fi
if [ "$REMOVE_DATA" = true ]; then
    log "  - Data and logs removed"
else
    log "  - Data and logs retained (use --remove-data to remove)"
fi
log ""
log "To remove everything:"
log "  ./scripts/step-O-cleanup.sh --remove-volumes --remove-data"
log ""
log "Log saved to: $LOG_FILE"
log ""
