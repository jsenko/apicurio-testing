#!/bin/bash

# Step A: Deploy Apicurio Registry 2.6.x with PostgreSQL
#
# This script:
# 1. Deploys PostgreSQL 14
# 2. Deploys Apicurio Registry 2.6.13.Final
# 3. Waits for health checks to pass
# 4. Verifies system info

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-A-deploy-v2.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step A: Deploy Apicurio Registry 2.6.13" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Navigate to project directory
cd "$PROJECT_DIR"

echo "[1/4] Starting containers..." | tee -a "$LOG_FILE"
docker compose -f docker-compose-v2.yml up -d 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[2/4] Waiting for PostgreSQL to be healthy..." | tee -a "$LOG_FILE"
RETRY_COUNT=0
MAX_RETRIES=30
until docker exec scenario1-postgres-v2 pg_isready -U apicurio -d registry > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ PostgreSQL failed to start after ${MAX_RETRIES} attempts" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo "" | tee -a "$LOG_FILE"
echo "✅ PostgreSQL is healthy" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[3/4] Waiting for Registry to be healthy..." | tee -a "$LOG_FILE"
"$SCRIPT_DIR/wait-for-health.sh" http://localhost:2222/health/live 120 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[4/4] Verifying system info..." | tee -a "$LOG_FILE"
SYSTEM_INFO=$(curl -s http://localhost:2222/apis/registry/v2/system/info)
echo "$SYSTEM_INFO" | jq '.' | tee -a "$LOG_FILE"

VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version')
echo "" | tee -a "$LOG_FILE"
echo "Registry Version: $VERSION" | tee -a "$LOG_FILE"

# Validate version is 2.6.x
if [[ "$VERSION" != 2.6.* ]]; then
    echo "❌ Expected version 2.6.x but got $VERSION" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✅ Step A completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry v2 is running at: http://localhost:2222" | tee -a "$LOG_FILE"
echo "PostgreSQL is running at: localhost:5432" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Container logs:" | tee -a "$LOG_FILE"
echo "  docker logs scenario1-postgres-v2" | tee -a "$LOG_FILE"
echo "  docker logs scenario1-registry-v2" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Collect initial container logs
echo "Collecting initial container logs..." | tee -a "$LOG_FILE"
docker logs scenario1-postgres-v2 > "$PROJECT_DIR/logs/containers/postgres-v2-initial.log" 2>&1
docker logs scenario1-registry-v2 > "$PROJECT_DIR/logs/containers/registry-v2-initial.log" 2>&1

echo "Logs saved to:" | tee -a "$LOG_FILE"
echo "  - $LOG_FILE" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/postgres-v2-initial.log" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/registry-v2-initial.log" | tee -a "$LOG_FILE"
