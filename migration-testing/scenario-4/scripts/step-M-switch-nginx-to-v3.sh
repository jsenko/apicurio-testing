#!/bin/bash

# Step M: Switch Nginx to Route to Registry v3
#
# This script:
# 1. Verifies v3 registry is running and has data
# 2. Updates nginx configuration to route to v3
# 3. Restarts nginx with the new configuration
# 4. Verifies the switch was successful

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"

LOG_FILE="$PROJECT_DIR/logs/step-M-switch-nginx-to-v3.log"
NGINX_COMPOSE="$PROJECT_DIR/docker-compose-nginx.yml"

# Verify v3 registry is running and has data
echo "[1/3] Verifying v3 registry is ready..." | tee -a "$LOG_FILE"

V3_URL="https://localhost:3333"
if ! curl -f -s -k "$V3_URL/apis/registry/v3/system/info" > /dev/null 2>&1; then
    echo "  ✗ Registry v3 is not accessible at $V3_URL" | tee -a "$LOG_FILE"
    echo "    Make sure step-G-deploy-v3.sh and step-H-import-v3-data.sh completed" | tee -a "$LOG_FILE"
    exit 1
fi

# Check artifact count
ARTIFACT_COUNT=$(curl -s -k "$V3_URL/apis/registry/v3/search/artifacts?limit=1" | jq -r '.count' 2>/dev/null || echo "0")
if [ "$ARTIFACT_COUNT" -lt 1 ]; then
    echo "  ✗ Registry v3 has no artifacts ($ARTIFACT_COUNT found)" | tee -a "$LOG_FILE"
    echo "    Make sure step-H-import-v3-data.sh completed" | tee -a "$LOG_FILE"
    exit 1
fi

echo "  ✓ Registry v3 is running with $ARTIFACT_COUNT artifacts" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Recreate nginx container with new configuration
echo "[2/3] Recreating nginx with new configuration..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR"

# Stop and remove the container to pick up new volume mounts
docker compose -f docker-compose-nginx-v2.yml down 2>&1 | tee -a "$LOG_FILE"

# Start with new configuration
docker compose -f docker-compose-nginx-v3.yml up -d 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "  Waiting for nginx to be healthy..." | tee -a "$LOG_FILE"
sleep 3

# Wait for nginx health check
MAX_WAIT=30
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -f -s "http://localhost:8081/nginx-health" > /dev/null 2>&1; then
        echo "  ✓ Nginx is healthy" | tee -a "$LOG_FILE"
        break
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "  ✗ Nginx failed to become healthy within ${MAX_WAIT}s" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Verify nginx is routing to v3
echo "[3/3] Verifying nginx is routing to v3..." | tee -a "$LOG_FILE"

# Check registry version through nginx
NGINX_REGISTRY_URL="https://localhost:8443/apis/registry/v3/system/info"
SYSTEM_INFO=$(curl -s -k "$NGINX_REGISTRY_URL")
VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version' 2>/dev/null || echo "unknown")

echo "  Registry version via nginx: $VERSION" | tee -a "$LOG_FILE"

if [[ "$VERSION" =~ ^3\.1\. ]]; then
    echo "  ✓ Nginx is successfully routing to v3 registry" | tee -a "$LOG_FILE"
else
    echo "  ✗ Version check failed - got: $VERSION" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

echo "================================================================" | tee -a "$LOG_FILE"
echo "Nginx successfully switched to route to Registry v3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry v3 (via nginx): https://localhost:8443" | tee -a "$LOG_FILE"
echo "Registry v3 (direct):    https://localhost:3333" | tee -a "$LOG_FILE"
echo "Registry v2 (direct):    https://localhost:2222" | tee -a "$LOG_FILE"
echo "Nginx health check:      http://localhost:8081/nginx-health" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Artifacts: $ARTIFACT_COUNT" | tee -a "$LOG_FILE"
echo "Version:   $VERSION" | tee -a "$LOG_FILE"
echo "Log:       $LOG_FILE" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
