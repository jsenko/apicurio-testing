#!/bin/bash

# Step I: Switch Nginx to Route to Registry v3
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

LOG_FILE="$PROJECT_DIR/logs/step-I-switch-nginx-to-v3.log"
NGINX_COMPOSE="$PROJECT_DIR/docker-compose-nginx.yml"

echo "================================================================" | tee "$LOG_FILE"
echo "  Step I: Switch Nginx to Route to Registry v3" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Verify v3 registry is running and has data
echo "[1/5] Verifying v3 registry is ready..." | tee -a "$LOG_FILE"

V3_URL="http://localhost:3333"
if ! curl -f -s "$V3_URL/apis/registry/v3/system/info" > /dev/null 2>&1; then
    echo "  ✗ Registry v3 is not accessible at $V3_URL" | tee -a "$LOG_FILE"
    echo "    Make sure step-G-deploy-v3.sh and step-H-import-v3-data.sh completed" | tee -a "$LOG_FILE"
    exit 1
fi

# Check artifact count
ARTIFACT_COUNT=$(curl -s "$V3_URL/apis/registry/v3/search/artifacts?limit=1" | jq -r '.count' 2>/dev/null || echo "0")
if [ "$ARTIFACT_COUNT" -lt 1 ]; then
    echo "  ✗ Registry v3 has no artifacts ($ARTIFACT_COUNT found)" | tee -a "$LOG_FILE"
    echo "    Make sure step-H-import-v3-data.sh completed" | tee -a "$LOG_FILE"
    exit 1
fi

echo "  ✓ Registry v3 is running with $ARTIFACT_COUNT artifacts" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Update nginx docker-compose to use v3 config
echo "[2/5] Updating nginx configuration..." | tee -a "$LOG_FILE"

# Check current configuration
CURRENT_MOUNT=$(grep "registry-v.*\.conf:/etc/nginx/conf.d/default.conf" "$NGINX_COMPOSE" || true)
echo "  Current: $CURRENT_MOUNT" | tee -a "$LOG_FILE"

# Update the configuration file
if grep -q "registry-v2.conf:/etc/nginx/conf.d/default.conf" "$NGINX_COMPOSE"; then
    sed -i 's|./nginx/conf.d/registry-v2.conf:/etc/nginx/conf.d/default.conf:ro|./nginx/conf.d/registry-v3.conf:/etc/nginx/conf.d/default.conf:ro|' "$NGINX_COMPOSE"
    echo "  ✓ Updated configuration to use registry-v3.conf" | tee -a "$LOG_FILE"
elif grep -q "registry-v3.conf:/etc/nginx/conf.d/default.conf" "$NGINX_COMPOSE"; then
    echo "  ✓ Configuration already set to registry-v3.conf" | tee -a "$LOG_FILE"
else
    echo "  ✗ Could not find nginx config mount in $NGINX_COMPOSE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Recreate nginx container with new configuration
echo "[3/5] Recreating nginx with new configuration..." | tee -a "$LOG_FILE"
cd "$PROJECT_DIR"

# Stop and remove the container to pick up new volume mounts
docker compose -f docker-compose-nginx.yml down 2>&1 | tee -a "$LOG_FILE"

# Start with new configuration
docker compose -f docker-compose-nginx.yml up -d 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "  Waiting for nginx to be healthy..." | tee -a "$LOG_FILE"
sleep 3

# Wait for nginx health check
MAX_WAIT=30
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if curl -f -s "http://localhost:8080/nginx-health" > /dev/null 2>&1; then
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
echo "[4/5] Verifying nginx is routing to v3..." | tee -a "$LOG_FILE"

# Check nginx health endpoint
HEALTH_RESPONSE=$(curl -s "http://localhost:8080/nginx-health")
echo "  Nginx health: $HEALTH_RESPONSE" | tee -a "$LOG_FILE"

if echo "$HEALTH_RESPONSE" | grep -q "routing to v3"; then
    echo "  ✓ Nginx health endpoint reports routing to v3" | tee -a "$LOG_FILE"
else
    echo "  ✗ Nginx health endpoint does not report v3 routing" | tee -a "$LOG_FILE"
    exit 1
fi

# Check registry version through nginx
NGINX_REGISTRY_URL="http://localhost:8080/apis/registry/v3/system/info"
SYSTEM_INFO=$(curl -s "$NGINX_REGISTRY_URL")
VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version' 2>/dev/null || echo "unknown")

echo "  Registry version via nginx: $VERSION" | tee -a "$LOG_FILE"

if [[ "$VERSION" =~ ^3\.1\. ]]; then
    echo "  ✓ Nginx is successfully routing to v3 registry" | tee -a "$LOG_FILE"
else
    echo "  ✗ Version check failed - got: $VERSION" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"

# Verify artifact count through nginx
echo "[5/5] Verifying data accessibility through nginx..." | tee -a "$LOG_FILE"

NGINX_SEARCH_URL="http://localhost:8080/apis/registry/v3/search/artifacts?limit=1"
NGINX_COUNT=$(curl -s "$NGINX_SEARCH_URL" | jq -r '.count' 2>/dev/null || echo "0")

echo "  Artifacts accessible via nginx: $NGINX_COUNT" | tee -a "$LOG_FILE"

if [ "$NGINX_COUNT" -eq "$ARTIFACT_COUNT" ]; then
    echo "  ✓ All artifacts accessible through nginx" | tee -a "$LOG_FILE"
else
    echo "  ✗ Artifact count mismatch (nginx: $NGINX_COUNT, direct: $ARTIFACT_COUNT)" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "  ✓ Step I completed successfully" | tee -a "$LOG_FILE"
echo "================================================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Nginx successfully switched to route to Registry v3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Registry v3 (via nginx): http://localhost:8080" | tee -a "$LOG_FILE"
echo "Registry v3 (direct):    http://localhost:3333" | tee -a "$LOG_FILE"
echo "Registry v2 (direct):    http://localhost:2222" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Artifacts: $ARTIFACT_COUNT" | tee -a "$LOG_FILE"
echo "Version:   $VERSION" | tee -a "$LOG_FILE"
echo "Log:       $LOG_FILE" | tee -a "$LOG_FILE"
