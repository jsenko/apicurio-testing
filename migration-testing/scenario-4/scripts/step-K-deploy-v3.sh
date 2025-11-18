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

# Start containers
echo "[1/5] Starting containers..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR"
docker compose -f docker-compose-v3.yml up -d 2>&1 | tee -a "$LOG_FILE"

# Wait for PostgreSQL to be healthy
echo "" | tee -a "$LOG_FILE"
echo "[2/5] Waiting for PostgreSQL to be healthy..." | tee -a "$LOG_FILE"

MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker inspect scenario4-postgres-v3 --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
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
    docker logs scenario4-postgres-v3 2>&1 | tee -a "$LOG_FILE"
    exit 1
fi

# Wait for Registry to be healthy
echo "" | tee -a "$LOG_FILE"
echo "[3/5] Waiting for Registry to be healthy..." | tee -a "$LOG_FILE"

HEALTH_URL="https://localhost:3333/health/live"
"$SCRIPT_DIR/wait-for-health.sh" "$HEALTH_URL" 120 2>&1 | tee -a "$LOG_FILE"

# Verify authentication is enforced
echo "" | tee -a "$LOG_FILE"
echo "[4/5] Verifying authentication is enforced..." | tee -a "$LOG_FILE"

# Try to access search endpoint without authentication - should fail with 401
SEARCH_URL="https://localhost:3333/apis/registry/v3/search/artifacts"
HTTP_CODE=$(curl -s -k -o /tmp/auth-test.txt -w "%{http_code}" "$SEARCH_URL")

if [ "$HTTP_CODE" -eq 401 ]; then
    echo "  ✓ Authentication is enforced (HTTP 401 without token)" | tee -a "$LOG_FILE"
elif [ "$HTTP_CODE" -eq 403 ]; then
    echo "  ✓ Authentication is enforced (HTTP 403 without token)" | tee -a "$LOG_FILE"
else
    echo "  ✗ WARNING: Expected HTTP 401/403 but got HTTP $HTTP_CODE" | tee -a "$LOG_FILE"
    echo "  Response:" | tee -a "$LOG_FILE"
    cat /tmp/auth-test.txt | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "  ⚠ Authentication may not be properly configured!" | tee -a "$LOG_FILE"
fi

rm -f /tmp/auth-test.txt

# Verify system info (system/info endpoint may allow unauthenticated access)
echo "" | tee -a "$LOG_FILE"
echo "[5/5] Verifying system info..." | tee -a "$LOG_FILE"
SYSTEM_INFO=$(curl -s -k https://localhost:3333/apis/registry/v3/system/info)
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
echo "Registry v3 is running at: http://localhost:3333" | tee -a "$LOG_FILE"
echo "PostgreSQL is running at: localhost:5433" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Container logs:" | tee -a "$LOG_FILE"
echo "  docker logs scenario4-postgres-v3" | tee -a "$LOG_FILE"
echo "  docker logs scenario4-registry-v3" | tee -a "$LOG_FILE"

# Collect initial container logs
echo "" | tee -a "$LOG_FILE"
echo "Collecting initial container logs..." | tee -a "$LOG_FILE"
docker logs scenario4-postgres-v3 > "$PROJECT_DIR/logs/containers/postgres-v3-initial.log" 2>&1 || true
docker logs scenario4-registry-v3 > "$PROJECT_DIR/logs/containers/registry-v3-initial.log" 2>&1 || true

echo "Logs saved to:" | tee -a "$LOG_FILE"
echo "  - $LOG_FILE" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/postgres-v3-initial.log" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/registry-v3-initial.log" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
