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

# Navigate to project directory
cd "$PROJECT_DIR"

echo "[1/5] Starting containers..." | tee -a "$LOG_FILE"
docker compose -f docker-compose-v2.yml up -d 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "[2/5] Waiting for PostgreSQL to be healthy..." | tee -a "$LOG_FILE"
RETRY_COUNT=0
MAX_RETRIES=30
until docker exec scenario4-postgres-v2 pg_isready -U apicurio -d registry > /dev/null 2>&1; do
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
echo "[3/5] Waiting for Registry to be healthy..." | tee -a "$LOG_FILE"
"$SCRIPT_DIR/wait-for-health.sh" https://localhost:2222/health/live 120 | tee -a "$LOG_FILE"

# Verify authentication is enforced
echo "" | tee -a "$LOG_FILE"
echo "[4/5] Verifying authentication is enforced..." | tee -a "$LOG_FILE"

# Try to access search endpoint without authentication - should fail with 401
SEARCH_URL="https://localhost:2222/apis/registry/v2/search/artifacts"
HTTP_CODE=$(curl -s -k -o /tmp/auth-test-v2.txt -w "%{http_code}" "$SEARCH_URL")

if [ "$HTTP_CODE" -eq 401 ]; then
    echo "  ✓ Authentication is enforced (HTTP 401 without token)" | tee -a "$LOG_FILE"
elif [ "$HTTP_CODE" -eq 403 ]; then
    echo "  ✓ Authentication is enforced (HTTP 403 without token)" | tee -a "$LOG_FILE"
else
    echo "  ✗ WARNING: Expected HTTP 401/403 but got HTTP $HTTP_CODE" | tee -a "$LOG_FILE"
    echo "  Response:" | tee -a "$LOG_FILE"
    cat /tmp/auth-test-v2.txt | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "  ⚠ Authentication may not be properly configured!" | tee -a "$LOG_FILE"
fi

rm -f /tmp/auth-test-v2.txt

echo "" | tee -a "$LOG_FILE"
echo "[5/5] Verifying system info..." | tee -a "$LOG_FILE"
SYSTEM_INFO=$(curl -s -k https://localhost:2222/apis/registry/v2/system/info)
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
echo "Registry v2 is running at: http://localhost:2222" | tee -a "$LOG_FILE"
echo "PostgreSQL is running at: localhost:5432" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Container logs:" | tee -a "$LOG_FILE"
echo "  docker logs scenario4-postgres-v2" | tee -a "$LOG_FILE"
echo "  docker logs scenario4-registry-v2" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Collect initial container logs
echo "Collecting initial container logs..." | tee -a "$LOG_FILE"
docker logs scenario4-postgres-v2 > "$PROJECT_DIR/logs/containers/postgres-v2-initial.log" 2>&1
docker logs scenario4-registry-v2 > "$PROJECT_DIR/logs/containers/registry-v2-initial.log" 2>&1

echo "Logs saved to:" | tee -a "$LOG_FILE"
echo "  - $LOG_FILE" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/postgres-v2-initial.log" | tee -a "$LOG_FILE"
echo "  - $PROJECT_DIR/logs/containers/registry-v2-initial.log" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
