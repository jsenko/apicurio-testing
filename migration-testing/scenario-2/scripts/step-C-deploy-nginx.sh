#!/bin/bash

# Step C: Deploy Nginx Load Balancer
#
# This script:
# 1. Deploys nginx reverse proxy
# 2. Configures routing to Registry v2
# 3. Verifies health checks
# 4. Tests registry access through nginx

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/logs/containers"

LOG_FILE="$PROJECT_DIR/logs/step-C-deploy-nginx.log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "================================================================"
log "  Step C: Deploy Nginx Load Balancer"
log "================================================================"
log ""

# Navigate to project directory
cd "$PROJECT_DIR"

log "[0/5] Verifying Registry v2 is running..."
if ! docker ps | grep -q scenario2-registry-v2; then
    log "❌ Registry v2 is not running. Please run step-B-deploy-v2-kafka.sh first."
    exit 1
fi
log "✅ Registry v2 is running"
log ""

log "[1/5] Creating v3 network (for future use)..."
if ! docker network inspect scenario2-v3-network > /dev/null 2>&1; then
    docker network create scenario2-v3-network 2>&1 | tee -a "$LOG_FILE"
    log "✅ Network 'scenario2-v3-network' created"
else
    log "ℹ️  Network 'scenario2-v3-network' already exists"
fi
log ""

log "[2/5] Starting nginx container..."
docker compose -f docker-compose-nginx.yml up -d 2>&1 | tee -a "$LOG_FILE"
log ""

log "[3/5] Waiting for nginx to be healthy..."
"$SCRIPT_DIR/wait-for-health.sh" http://localhost:8080/nginx-health 30 2>&1 | tee -a "$LOG_FILE"
log ""

log "[4/5] Verifying nginx health endpoint..."
NGINX_HEALTH=$(curl -s http://localhost:8080/nginx-health)
log "Nginx health response: $NGINX_HEALTH"
log ""

log "[5/5] Verifying registry is accessible through nginx..."
SYSTEM_INFO=$(curl -s http://localhost:8080/apis/registry/v2/system/info)
echo "$SYSTEM_INFO" | jq '.' 2>&1 | tee -a "$LOG_FILE"
log ""

VERSION=$(echo "$SYSTEM_INFO" | jq -r '.version')
log "Registry Version (via nginx): $VERSION"

# Validate version is 2.6.x
if [[ "$VERSION" != 2.6.* ]]; then
    log "❌ Expected version 2.6.x but got $VERSION"
    exit 1
fi
log ""

log "================================================================"
log "  ✅ Step C completed successfully"
log "================================================================"
log ""
log "Nginx is running at: http://localhost:8080"
log "Currently routing to: Registry v2 (2.6.x)"
log ""
log "Test endpoints through nginx:"
log "  curl http://localhost:8080/nginx-health"
log "  curl http://localhost:8080/apis/registry/v2/system/info"
log ""
log "Container logs:"
log "  docker logs scenario2-nginx"
log ""

# Collect nginx logs
log "Collecting nginx logs..."
docker logs scenario2-nginx > "$PROJECT_DIR/logs/containers/nginx-initial.log" 2>&1

log "Logs saved to:"
log "  - $LOG_FILE"
log "  - $PROJECT_DIR/logs/containers/nginx-initial.log"
log ""
