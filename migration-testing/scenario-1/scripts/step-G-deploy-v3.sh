#!/bin/bash

# Step G: Deploy Apicurio Registry 3.1.2
#
# This script:
# 1. Deploys PostgreSQL database for v3
# 2. Deploys Apicurio Registry v3.1.2
# 3. Waits for services to be healthy
# 4. Verifies the deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-G-deploy-v3.log"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step G: Deploy Apicurio Registry 3.1.2" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Start containers
echo "[1/4] Starting containers..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR"
docker compose -f docker-compose-v3.yml up -d 2>&1 | tee -a "$LOG_FILE"

# Wait for PostgreSQL to be healthy
echo "" | tee -a "$LOG_FILE"
echo "[2/4] Waiting for PostgreSQL to be healthy..." | tee -a "$LOG_FILE"

MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker inspect scenario1-postgres-v3 --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        echo "" | tee -a "$LOG_FILE"
        echo "✅ PostgreSQL is healthy" | tee -a "$LOG_FILE"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "❌ PostgreSQL failed to become healthy within ${MAX_WAIT}s" | tee -a "$LOG_FILE"
    docker logs scenario1-postgres-v3 2>&1 | tee -a "$LOG_FILE"
    exit 1
fi

# Wait for Registry to be healthy
echo "" | tee -a "$LOG_FILE"
echo "[3/4] Waiting for Registry to be healthy..." | tee -a "$LOG_FILE"

HEALTH_URL="http://localhost:3333/health/live"
"$SCRIPT_DIR/wait-for-health.sh" "$HEALTH_URL" 120 2>&1 | tee -a "$LOG_FILE"

# Verify system info
echo "" | tee -a "$LOG_FILE"
echo "[4/4] Verifying system info..." | tee -a "$LOG_FILE"
SYSTEM_INFO=$(curl -s http://localhost:3333/apis/registry/v3/system/info)
echo "$SYSTEM_INFO" | jq . 2>&1 | tee -a "$LOG_FILE"

# Extract version
VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version' 2>/dev/null || echo "unknown")
echo "" | tee -a "$LOG_FILE"
echo "Registry Version: $VERSION" | tee -a "$LOG_FILE"

if [[ ! "$VERSION" =~ ^3\.1\. ]]; then
    echo "" | tee -a "$LOG_FILE"
    echo "⚠️  Warning: Expected version 3.1.x but got: $VERSION" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✅ Step G completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry v3 is running at: http://localhost:3333" | tee -a "$LOG_FILE"
echo "PostgreSQL is running at: localhost:5433" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Container logs:" | tee -a "$LOG_FILE"
echo "  docker logs scenario1-postgres-v3" | tee -a "$LOG_FILE"
echo "  docker logs scenario1-registry-v3" | tee -a "$LOG_FILE"

# Collect initial container logs
echo "" | tee -a "$LOG_FILE"
echo "Collecting initial container logs..." | tee -a "$LOG_FILE"
docker logs scenario1-postgres-v3 > "$PROJECT_DIR/logs/containers/postgres-v3-initial.log" 2>&1 || true
docker logs scenario1-registry-v3 > "$PROJECT_DIR/logs/containers/registry-v3-initial.log" 2>&1 || true

echo "Logs saved to:" | tee -a "$LOG_FILE"
echo "  - $LOG_FILE" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/postgres-v3-initial.log" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/registry-v3-initial.log" | tee -a "$LOG_FILE"
