#!/bin/bash

# Step J: Switch Nginx to Route to Registry v3
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
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-J-switch-nginx-to-v3.log"
NGINX_COMPOSE="$PROJECT_DIR/docker-compose-nginx.yml"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step J: Switch Nginx to Route to Registry v3"
log "================================================================"
log ""

# Verify v3 registry is running and has data
log "[1/5] Verifying v3 registry is ready..."

V3_URL="http://localhost:3333"
if ! curl -f -s "$V3_URL/apis/registry/v3/system/info" > /dev/null 2>&1; then
    log "❌ Registry v3 is not accessible at $V3_URL"
    log "   Make sure step-H-deploy-v3-kafka.sh and step-I-import-v3-data.sh completed"
    exit 1
fi

# Check artifact count
ARTIFACT_COUNT=$(curl -s "$V3_URL/apis/registry/v3/search/artifacts?limit=1" | jq -r '.count' 2>/dev/null || echo "0")
if [ "$ARTIFACT_COUNT" -lt 1 ]; then
    log "❌ Registry v3 has no artifacts ($ARTIFACT_COUNT found)"
    log "   Make sure step-I-import-v3-data.sh completed"
    exit 1
fi

log "✅ Registry v3 is running with $ARTIFACT_COUNT artifacts"
log ""

# Update nginx docker-compose to use v3 config
log "[2/5] Updating nginx configuration..."

# Check current configuration
CURRENT_MOUNT=$(grep "registry-v.*\.conf:/etc/nginx/conf.d/default.conf" "$NGINX_COMPOSE" || true)
log "  Current: $CURRENT_MOUNT"

# Update the configuration file
if grep -q "registry-v2.conf:/etc/nginx/conf.d/default.conf" "$NGINX_COMPOSE"; then
    sed -i 's|./nginx/conf.d/registry-v2.conf:/etc/nginx/conf.d/default.conf:ro|./nginx/conf.d/registry-v3.conf:/etc/nginx/conf.d/default.conf:ro|' "$NGINX_COMPOSE"
    log "✅ Updated configuration to use registry-v3.conf"
elif grep -q "registry-v3.conf:/etc/nginx/conf.d/default.conf" "$NGINX_COMPOSE"; then
    log "✅ Configuration already set to registry-v3.conf"
else
    log "❌ Could not find nginx config mount in $NGINX_COMPOSE"
    exit 1
fi

log ""

# Recreate nginx container with new configuration
log "[3/5] Recreating nginx with new configuration..."
cd "$PROJECT_DIR"

# Stop and remove the container to pick up new volume mounts
docker compose -f docker-compose-nginx.yml down 2>&1 | tee -a "$LOG_FILE"

# Start with new configuration
docker compose -f docker-compose-nginx.yml up -d 2>&1 | tee -a "$LOG_FILE"

log ""
log "Waiting for nginx to be healthy..."
sleep 3

# Wait for nginx health
"$SCRIPT_DIR/wait-for-health.sh" http://localhost:8080/nginx-health 30 2>&1 | tee -a "$LOG_FILE"
log ""

# Verify nginx is now routing to v3
log "[4/5] Verifying nginx is routing to v3..."

# Check nginx health endpoint
NGINX_HEALTH=$(curl -s http://localhost:8080/nginx-health)
log "  Nginx health: $NGINX_HEALTH"

if echo "$NGINX_HEALTH" | grep -q "v3"; then
    log "✅ Nginx health confirms routing to v3"
else
    log "⚠️  Nginx health does not confirm v3 routing"
fi

# Check system info through nginx
SYSTEM_INFO=$(curl -s http://localhost:8080/apis/registry/v3/system/info)
VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version')
log "  Registry version via nginx: $VERSION"

if [[ "$VERSION" == 3.* ]]; then
    log "✅ Confirmed routing to v3 (version $VERSION)"
else
    log "❌ Not routing to v3 correctly (version: $VERSION)"
    exit 1
fi
log ""

# Verify artifacts are accessible through nginx
log "[5/5] Verifying artifacts accessible through nginx..."
NGINX_ARTIFACT_COUNT=$(curl -s "http://localhost:8080/apis/registry/v3/search/artifacts?limit=1" | jq -r '.count' 2>/dev/null || echo "0")
log "  Artifacts via nginx: $NGINX_ARTIFACT_COUNT"

if [ "$NGINX_ARTIFACT_COUNT" -eq "$ARTIFACT_COUNT" ]; then
    log "✅ Artifact count matches ($NGINX_ARTIFACT_COUNT)"
else
    log "⚠️  Artifact count mismatch (direct: $ARTIFACT_COUNT, nginx: $NGINX_ARTIFACT_COUNT)"
fi
log ""

# Collect nginx logs after switch
log "Collecting nginx logs after switch..."
docker logs scenario2-nginx > "$PROJECT_DIR/logs/containers/nginx-after-switch.log" 2>&1

log "================================================================"
log "  ✅ Step J completed successfully"
log "================================================================"
log ""
log "Migration Traffic Switch Summary:"
log "  - Nginx now routing to: Registry v3 (3.x)"
log "  - Previous routing: Registry v2 (2.6.x)"
log "  - Artifacts accessible: $NGINX_ARTIFACT_COUNT"
log ""
log "All traffic now flows through v3!"
log ""
log "Test endpoints (should now return v3 data):"
log "  curl http://localhost:8080/nginx-health"
log "  curl http://localhost:8080/apis/registry/v3/system/info"
log "  curl http://localhost:8080/apis/registry/v3/search/artifacts"
log ""
log "Direct v3 access still available at:"
log "  http://localhost:3333"
log ""
log "Logs saved to:"
log "  - $LOG_FILE"
log "  - $PROJECT_DIR/logs/containers/nginx-after-switch.log"
log ""
